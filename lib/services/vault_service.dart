import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import '../models/safe_item.dart';
import "../models/container_data.dart";
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultService {
  static const _indexKey = 'vault_index';
  static const _saltKey = 'vault_salt';
  static const _storagePathKey = 'vault_storage_path';
  static const _indexRecordKey = 'vault_index_record';
  static const _indexPayloadKey = 'vault_index_payload';
  static const _indexMacKey = 'vault_index_mac';
  static const _indexSecretKey = 'vault_index_secret';
  static const _keyIterations = 1000000;
  static const _streamMagic = [65, 87, 83, 65, 70, 69, 48, 49];
  static const _streamChunkBytes = 1024 * 1024;
  static const _nonceBytes = 12;
  static const _macBytes = 16;

  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _cachedPreferences;
  Future<SharedPreferences> get _preferences async =>
      _cachedPreferences ??= await SharedPreferences.getInstance();
  Directory? _cachedVaultDirectory;
  String? _cachedIndexSecret;
  static const _wipeChunkBytes = 64 * 1024;
  Future<void> _operation = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _operation;
    final release = Completer<void>();
    _operation = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  Future<String> storageLocation() async {
    final preferences = await _preferences;
    final configuredPath = preferences.getString(_storagePathKey);
    if (configuredPath != null) {
      return configuredPath;
    }
    final root = await getApplicationSupportDirectory();
    return '${root.path}/vault';
  }

  Future<void> changeStorageDirectory(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw const FormatException('O local não pode ficar vazio.');
    }
    return _exclusive(() async {
      final destination = Directory(normalizedPath);
      await destination.create(recursive: true);
      final current = await _vaultDirectory();
      if (current.absolute.path != destination.absolute.path) {
        final currentPath = current.absolute.path;
        final destinationPath = destination.absolute.path;
        if (destinationPath
            .startsWith('$currentPath${Platform.pathSeparator}')) {
          throw const FormatException(
              'O novo local não pode ficar dentro do cofre atual.');
        }
        final staging =
            Directory('${destination.path}/.awesome_safe_migration');
        await staging.create(recursive: true);
        try {
          await for (final entity in current.list()) {
            if (entity is File && entity.path.endsWith('.safe')) {
              final fileName = entity.path.split(RegExp(r'[\\/]')).last;
              final destinationFile = File('${destination.path}/$fileName');
              if (await destinationFile.exists()) {
                throw const FileSystemException(
                    'O destino já contém um envelope do cofre.');
              }
              await entity.copy('${staging.path}/$fileName');
            }
          }
          await for (final entity in staging.list()) {
            if (entity is File) {
              final fileName = entity.path.split(RegExp(r'[\\/]')).last;
              await entity.rename('${destination.path}/$fileName');
            }
          }
          await for (final entity in current.list()) {
            if (entity is File && entity.path.endsWith('.safe')) {
              await _secureDelete(entity);
            }
          }
        } finally {
          if (await staging.exists()) {
            await staging.delete(recursive: true);
          }
        }
      }
      final preferences = await _preferences;
      await preferences.setString(_storagePathKey, destination.path);
      _cachedVaultDirectory = destination;
    });
  }

  File _containerFile(Directory directory) =>
      File('${directory.path}/vault.safe');

  Future<List<SafeItem>> loadItems() async {
    final preferences = await _preferences;
    final record = preferences.getString(_indexRecordKey);
    final payload =
        record == null ? preferences.getString(_indexPayloadKey) : null;
    if (payload != null) {
      final expectedMac = preferences.getString(_indexMacKey);
      final actualMac = await _indexMac(payload);
      if (expectedMac != actualMac) {
        throw const FormatException(
            'O índice do cofre foi alterado ou está corrompido.');
      }
      return _decodeItems(payload);
    }
    if (record != null) {
      final decoded = jsonDecode(record) as Map<String, dynamic>;
      final recordPayload = decoded['payload'] as String;
      final expectedMac = decoded['mac'] as String;
      if (expectedMac != await _indexMac(recordPayload)) {
        throw const FormatException(
            'O índice do cofre foi alterado ou está corrompido.');
      }
      return _decodeItems(recordPayload);
    }
    final raw = preferences.getStringList(_indexKey) ?? const [];
    return _sortItems(raw.map((entry) =>
        SafeItem.fromJson(jsonDecode(entry) as Map<String, dynamic>)));
  }

  Future<void> saveFile({
    required String password,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) =>
      saveFileStream(
          password: password,
          fileName: fileName,
          mimeType: mimeType,
          bytes: Stream<List<int>>.value(bytes));

  Future<void> saveFileStream(
          {required String password,
          required String fileName,
          required String mimeType,
          required Stream<List<int>> bytes}) async =>
      _exclusive(() async {
        _validateFile(fileName: fileName, mimeType: mimeType);
        _validateNewPassword(password);
        final items = await loadItems();
        final directory = await _vaultDirectory();
        final containerFile = _containerFile(directory);
        final existingContainer = await _readContainerUnsafe(password);
        final container = existingContainer == null
            ? ContainerData(
                version: 1,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                files: [],
              )
            : ContainerData(
                version: existingContainer.version,
                createdAt: existingContainer.createdAt,
                updatedAt: existingContainer.updatedAt,
                files: existingContainer.files
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList(),
              );

        final migratedFiles = <File>[];
        for (final item in items) {
          if (container.files.any((entry) => entry['id'] == item.id)) {
            continue;
          }
          final legacyFile = File('${directory.path}/${item.id}.safe');
          if (!await legacyFile.exists()) continue;
          final legacyBytes =
              await _readFileUnsafe(password: password, item: item);
          container.files.add({
            'id': item.id,
            'fileName': item.fileName,
            'mimeType': item.mimeType,
            'byteLength': item.byteLength,
            'createdAt': item.createdAt.toIso8601String(),
            'data': base64Encode(legacyBytes),
          });
          migratedFiles.add(legacyFile);
        }

        var id = DateTime.now().microsecondsSinceEpoch.toString();
        while (items.any((item) => item.id == id)) {
          id = (int.parse(id) + 1).toString();
        }
        final now = DateTime.now();
        final content = BytesBuilder(copy: false);
        var byteLength = 0;
        await for (final chunk in bytes) {
          content.add(chunk);
          byteLength += chunk.length;
        }
        final item = SafeItem(
          id: id,
          fileName: fileName.trim(),
          mimeType: mimeType.trim(),
          byteLength: byteLength,
          createdAt: now,
        );
        container.files.add({
          'id': item.id,
          'fileName': item.fileName,
          'mimeType': item.mimeType,
          'byteLength': item.byteLength,
          'createdAt': item.createdAt.toIso8601String(),
          'data': base64Encode(content.takeBytes()),
        });
        final updatedContainer = ContainerData(
          version: container.version,
          createdAt: container.createdAt,
          updatedAt: now,
          files: container.files,
        );
        await _writeContainerUnsafe(password, updatedContainer);
        try {
          items.add(item);
          await _saveIndex(items);
        } catch (_) {
          if (existingContainer == null) {
            await _secureDelete(containerFile);
          } else {
            await _writeContainerUnsafe(password, existingContainer);
          }
          rethrow;
        }
        for (final legacyFile in migratedFiles) {
          await _secureDelete(legacyFile);
        }
      });

  Future<Uint8List> readFile(
      {required String password, required SafeItem item}) async {
    return _exclusive(() => _readFileUnsafe(password: password, item: item));
  }

  /// Leitura em streaming para arquivos grandes.
  /// Mantém o método readFile() compatível com o código existente,
  /// mas permite que novos consumidores processem os dados por chunks
  /// sem acumular o arquivo inteiro na memória.
  Stream<List<int>> readFileStream(
          {required String password, required SafeItem item}) =>
      _readFileStreamUnsafe(password: password, item: item);

  Stream<List<int>> _readFileStreamUnsafe(
      {required String password, required SafeItem item}) async* {
    final directory = await _vaultDirectory();
    final containerFile = _containerFile(directory);
    if (await containerFile.exists()) {
      final container = await _readContainerUnsafe(password);
      if (container != null) {
        final match = container.files.firstWhere(
            (entry) =>
                entry['id'] == item.id || entry['fileName'] == item.fileName,
            orElse: () => const {});
        if (match.isNotEmpty && match['data'] != null) {
          yield Uint8List.fromList(base64Decode(match['data'] as String));
          return;
        }
      }
    }

    final legacyFile = File('${directory.path}/${item.id}.safe');
    if (await legacyFile.exists()) {
      try {
        if (await _hasStreamFormat(legacyFile)) {
          await for (final chunk
              in _decryptedChunkStream(legacyFile, password)) {
            yield chunk;
          }
          return;
        }

        final envelope =
            jsonDecode(await legacyFile.readAsString()) as Map<String, dynamic>;
        final decrypted =
            await Isolate.run(() => _decryptInIsolate(envelope, password));
        yield decrypted;
        return;
      } catch (_) {
        throw const FormatException(
          'Senha incorreta ou arquivo danificado.',
        );
      }
    }

    throw const FormatException('Arquivo não encontrado no cofre.');
  }

  Future<Uint8List> _readFileUnsafe(
      {required String password, required SafeItem item}) async {
    final directory = await _vaultDirectory();
    final containerFile = _containerFile(directory);

    if (await containerFile.exists()) {
      final container = await _readContainerUnsafe(password);
      if (container != null) {
        final match = container.files.firstWhere(
          (entry) =>
              entry['id'] == item.id || entry['fileName'] == item.fileName,
          orElse: () => const {},
        );
        if (match.isNotEmpty && match['data'] != null) {
          return Uint8List.fromList(base64Decode(match['data'] as String));
        }
      }
    }

    final legacyFile = File('${directory.path}/${item.id}.safe');
    if (await legacyFile.exists()) {
      try {
        if (await _hasStreamFormat(legacyFile)) {
          return await _readChunkedFile(legacyFile, password);
        }
        final envelope =
            jsonDecode(await legacyFile.readAsString()) as Map<String, dynamic>;
        final decrypted =
            await Isolate.run(() => _decryptInIsolate(envelope, password));
        return decrypted;
      } catch (_) {
        throw const FormatException('Senha incorreta ou arquivo danificado.');
      }
    }

    throw const FormatException('Arquivo não encontrado no cofre.');
  }

  Future<ContainerData?> _readContainerUnsafe(String password) async {
    final directory = await _vaultDirectory();
    final file = _containerFile(directory);
    final backupFile = File('${file.path}.bak');
    // Auto-recuperação: se o arquivo principal não existir mas existir backup
    if (!await file.exists() || (await file.length()) == 0) {
      if (await backupFile.exists() && (await backupFile.length()) > 0) {
        await backupFile.copy(file.path);
      } else {
        return null;
      }
    }
    try {
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final decryptedBytes =
          await Isolate.run(() => _decryptInIsolate(envelope, password));
      final payloadJson =
          jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      return ContainerData.fromJson(payloadJson);
    } catch (_) {
      // Tenta recuperar a partir do backup se o arquivo principal falhou
      if (await backupFile.exists() && (await backupFile.length()) > 0) {
        try {
          final backupEnvelope = jsonDecode(await backupFile.readAsString())
              as Map<String, dynamic>;
          final decryptedBytes = await Isolate.run(
              () => _decryptInIsolate(backupEnvelope, password));
          final payloadJson =
              jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
          await backupFile.copy(file.path);
          return ContainerData.fromJson(payloadJson);
        } catch (_) {}
      }
      throw const FormatException('Senha incorreta ou container danificado.');
    }
  }

  Future<void> _writeContainerUnsafe(
    String password,
    ContainerData container, {
    bool wipePrevious = false,
  }) async {
    final directory = await _vaultDirectory();
    final target = _containerFile(directory);
    final payloadBytes = utf8.encode(jsonEncode(container.toJson()));
    final envelope =
        await Isolate.run(() => _encryptInIsolate(payloadBytes, password));
    envelope['format'] = 'awesome_safe_container';
    envelope['version'] = 1;
    await _writeAtomically(target, envelope, wipePrevious: wipePrevious);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _exclusive(() async {
      if (currentPassword.isEmpty) {
        throw const FormatException('Informe a senha atual.');
      }
      _validateNewPassword(newPassword);
      final directory = await _vaultDirectory();
      final containerFile = _containerFile(directory);
      final items = await loadItems();

      if (await containerFile.exists()) {
        final container = await _readContainerUnsafe(currentPassword);
        if (container == null) {
          throw const FormatException(
              'Não foi possível abrir o container com a senha atual.');
        }
        final updated = ContainerData(
          version: container.version,
          createdAt: container.createdAt,
          updatedAt: DateTime.now(),
          files: container.files,
        );
        await _writeContainerUnsafe(newPassword, updated);
      } else if (items.isNotEmpty) {
        // Migra arquivos legados para container .safe na troca de senha
        final migratedFiles = <Map<String, dynamic>>[];
        for (final item in items) {
          final legacyFile = File('${directory.path}/${item.id}.safe');
          if (await legacyFile.exists() &&
              !await _hasStreamFormat(legacyFile)) {
            final bytes =
                await _readFileUnsafe(password: currentPassword, item: item);
            migratedFiles.add({
              'id': item.id,
              'fileName': item.fileName,
              'mimeType': item.mimeType,
              'byteLength': item.byteLength,
              'createdAt': item.createdAt.toIso8601String(),
              'data': base64Encode(bytes)
            });
            await _secureDelete(legacyFile);
          }
        }
        if (migratedFiles.isNotEmpty) {
          final newContainer = ContainerData(
            version: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            files: migratedFiles,
          );
          await _writeContainerUnsafe(newPassword, newContainer);
        }
      }

      for (final item in items) {
        final encryptedFile = File('${directory.path}/${item.id}.safe');
        if (await encryptedFile.exists() &&
            await _hasStreamFormat(encryptedFile)) {
          await _rekeyChunkedFile(encryptedFile,
              currentPassword: currentPassword, newPassword: newPassword);
        }
      }
    });
  }

  Future<void> deleteFile(SafeItem item, {String? password}) async {
    return _exclusive(() async {
      final directory = await _vaultDirectory();
      final containerFile = _containerFile(directory);
      final items = await loadItems();
      Object? cleanupFailure;
      var containerUpdated = false;

      if (await containerFile.exists()) {
        if (password != null && password.isNotEmpty) {
          final container = await _readContainerUnsafe(password);
          if (container != null) {
            container.files.removeWhere((entry) =>
                entry['id'] == item.id || entry['fileName'] == item.fileName);
            if (container.files.isEmpty) {
              await _secureDelete(containerFile);
              final backupFile = File('${containerFile.path}.bak');
              if (await backupFile.exists()) {
                try {
                  await _secureDelete(backupFile);
                } catch (error) {
                  cleanupFailure = error;
                }
              }
              containerUpdated = true;
            } else {
              final updated = ContainerData(
                version: container.version,
                createdAt: container.createdAt,
                updatedAt: DateTime.now(),
                files: container.files,
              );
              try {
                await _writeContainerUnsafe(
                  password,
                  updated,
                  wipePrevious: true,
                );
              } on _PostCommitCleanupException catch (error) {
                cleanupFailure = error;
              }
              containerUpdated = true;
            }
          }
        } else {
          if (items.length <= 1) {
            await _secureDelete(containerFile);
            final backupFile = File('${containerFile.path}.bak');
            if (await backupFile.exists()) {
              try {
                await _secureDelete(backupFile);
              } catch (error) {
                cleanupFailure = error;
              }
            }
            containerUpdated = true;
          } else {
            throw const FormatException(
                'Informe a senha do cofre para atualizar o container.');
          }
        }
      }
      final legacyFile = File('${directory.path}/${item.id}.safe');
      if (await legacyFile.exists()) {
        try {
          await _secureDelete(legacyFile);
        } catch (error) {
          if (!containerUpdated) rethrow;
          cleanupFailure ??= error;
        }
      }
      items.removeWhere((entry) => entry.id == item.id);
      await _saveIndex(items);
      if (cleanupFailure != null) {
        throw FileSystemException(
          'O item foi removido, mas não foi possível sobrescrever '
          'todos os dados antigos. Dados ainda podem permanecer no armazenamento: '
          '$cleanupFailure',
          legacyFile.path,
        );
      }
    });
  }

  Future<void> clearVault() async {
    return _exclusive(() async {
      final directory = await _vaultDirectory();

      // Remove todos os artefatos do vault, inclusive backups e temporários
      // deixados por operações atômicas ou troca de senha interrompidas.
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }

        final fileName = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;

        final isVaultArtifact = fileName.endsWith('.safe') ||
            fileName.endsWith('.safe.bak') ||
            fileName.contains('.safe.tmp-') ||
            fileName.contains('.safe.rekey-') ||
            fileName.contains('.safe.rekey-backup-');

        if (isVaultArtifact) {
          await _secureDelete(entity);
        }
      }

      final preferences = await _preferences;
      await preferences.remove(_indexKey);
      await preferences.remove(_indexRecordKey);
      await preferences.remove(_indexPayloadKey);
      await preferences.remove(_indexMacKey);
      await _deleteIndexSecret(preferences);
      await preferences.remove(_saltKey);
      await preferences.remove(_storagePathKey);
      _cachedVaultDirectory = null;
      _cachedIndexSecret = null;
    });
  }

  static Future<Map<String, dynamic>> _encryptInIsolate(
      List<int> bytes, String password) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final cipher = AesGcm.with256bits();
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _keyIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final secretBox = await cipher.encrypt(bytes, secretKey: key);
    return {
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'cipherText': base64Encode(secretBox.cipherText),
    };
  }

  static Future<Uint8List> _decryptInIsolate(
      Map<String, dynamic> envelope, String password) async {
    final salt = base64Decode(envelope['salt'] as String);
    final cipher = AesGcm.with256bits();
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _keyIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final box = SecretBox(
      base64Decode(envelope['cipherText'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)),
    );
    final decrypted = await cipher.decrypt(box, secretKey: key);
    return Uint8List.fromList(decrypted);
  }

  void _validateFile({required String fileName, required String mimeType}) {
    final cleanName = fileName.trim();
    if (cleanName.isEmpty || cleanName == '.' || cleanName == '..') {
      throw const FormatException('O nome do arquivo é inválido.');
    }
    if (cleanName.contains('/') || cleanName.contains('\\')) {
      throw const FormatException(
          'O nome do arquivo não pode conter caminhos.');
    }
    if (mimeType.trim().isEmpty) {
      throw const FormatException('O tipo do arquivo é inválido.');
    }
  }

  Future<int> _writeChunkedFile({
    required File target,
    required String password,
    required Stream<List<int>> bytes,
  }) async {
    final temporary =
        File('${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final cipher = AesGcm.with256bits();
    final key = await _deriveContentKey(password, salt);
    final handle = await temporary.open(mode: FileMode.writeOnly);
    var totalBytes = 0;
    var sequence = 0;
    final buffer = Uint8List(_streamChunkBytes);
    var bufferedBytes = 0;
    try {
      final header = Uint8List(_streamMagic.length + salt.length)
        ..setRange(0, _streamMagic.length, _streamMagic)
        ..setRange(
            _streamMagic.length, _streamMagic.length + salt.length, salt);
      await handle.writeFrom(header);
      await for (final input in bytes) {
        var offset = 0;
        while (offset < input.length) {
          if (bufferedBytes == 0 &&
              input is Uint8List &&
              input.length - offset >= buffer.length) {
            await _writeChunkRecord(
              handle,
              cipher,
              key,
              Uint8List.sublistView(input, offset, offset + buffer.length),
              sequence++,
            );
            offset += buffer.length;
            totalBytes += buffer.length;
            continue;
          }
          final count =
              min(buffer.length - bufferedBytes, input.length - offset);
          buffer.setRange(bufferedBytes, bufferedBytes + count, input, offset);
          bufferedBytes += count;
          offset += count;
          totalBytes += count;
          if (bufferedBytes == buffer.length) {
            await _writeChunkRecord(
              handle,
              cipher,
              key,
              buffer,
              sequence++,
            );
            bufferedBytes = 0;
          }
        }
      }
      if (bufferedBytes > 0) {
        await _writeChunkRecord(
          handle,
          cipher,
          key,
          Uint8List.sublistView(buffer, 0, bufferedBytes),
          sequence++,
        );
      }
      final finalBox = await cipher.encrypt(
        const [],
        secretKey: key,
        aad: _sequenceAad(sequence, isFinal: true),
      );
      final finalRecord =
          Uint8List(4 + finalBox.nonce.length + finalBox.mac.bytes.length);
      ByteData.sublistView(finalRecord).setInt32(0, -1, Endian.big);
      finalRecord
        ..setRange(4, 4 + finalBox.nonce.length, finalBox.nonce)
        ..setRange(
          4 + finalBox.nonce.length,
          finalRecord.length,
          finalBox.mac.bytes,
        );
      await handle.writeFrom(finalRecord);
      await handle.flush();
    } catch (_) {
      await handle.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    await handle.close();
    if (await target.exists()) {
      await temporary.delete();
      throw const FileSystemException('O arquivo já existe no cofre.');
    }
    try {
      await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    return totalBytes;
  }

  Future<void> _writeChunkRecord(
    RandomAccessFile handle,
    AesGcm cipher,
    SecretKey key,
    List<int> bytes,
    int sequence,
  ) async {
    final box = await cipher.encrypt(
      bytes,
      secretKey: key,
      aad: _sequenceAad(sequence),
    );
    final header = Uint8List(4 + box.nonce.length + box.mac.bytes.length);
    ByteData.sublistView(header).setInt32(0, bytes.length, Endian.big);
    header.setRange(4, 4 + box.nonce.length, box.nonce);
    header.setRange(4 + box.nonce.length, header.length, box.mac.bytes);
    await handle.writeFrom(header);
    await handle.writeFrom(box.cipherText);
    if (sequence % 2 == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Uint8List> _readChunkedFile(File file, String password) async {
    final handle = await file.open();
    try {
      final magic = await _readExactly(handle, _streamMagic.length);
      if (!_sameBytes(magic, _streamMagic)) {
        throw const FormatException('Formato de arquivo protegido inválido.');
      }
      final salt = await _readExactly(handle, 16);
      final cipher = AesGcm.with256bits();
      final key = await _deriveContentKey(password, salt);
      final builder = BytesBuilder(copy: false);
      var sequence = 0;
      while (true) {
        final lengthBytes = await _readExactly(handle, 4);
        final length =
            ByteData.sublistView(lengthBytes).getInt32(0, Endian.big);
        if (length == -1) {
          final nonce = await _readExactly(handle, _nonceBytes);
          final mac = await _readExactly(handle, _macBytes);
          await cipher.decrypt(
            SecretBox(const [], nonce: nonce, mac: Mac(mac)),
            secretKey: key,
            aad: _sequenceAad(sequence, isFinal: true),
          );
          if ((await handle.read(1)).isNotEmpty) {
            throw const FormatException('Dados extras no arquivo protegido.');
          }
          break;
        }
        if (length <= 0 || length > _streamChunkBytes) {
          throw const FormatException('Bloco inválido no arquivo protegido.');
        }
        final nonce = await _readExactly(handle, _nonceBytes);
        final mac = await _readExactly(handle, _macBytes);
        final encryptedBytes = await _readExactly(handle, length);
        final clearBytes = await cipher.decrypt(
          SecretBox(encryptedBytes, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: _sequenceAad(sequence++),
        );
        builder.add(clearBytes);
        if (sequence % 2 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      return builder.takeBytes();
    } finally {
      await handle.close();
    }
  }

  Stream<List<int>> _decryptedChunkStream(File file, String password) async* {
    final handle = await file.open();
    try {
      final magic = await _readExactly(handle, _streamMagic.length);
      if (!_sameBytes(magic, _streamMagic)) {
        throw const FormatException('Formato de arquivo protegido inválido.');
      }
      final salt = await _readExactly(handle, 16);
      final cipher = AesGcm.with256bits();
      final key = await _deriveContentKey(password, salt);
      var sequence = 0;
      while (true) {
        final lengthBytes = await _readExactly(handle, 4);
        final length =
            ByteData.sublistView(lengthBytes).getInt32(0, Endian.big);
        if (length == -1) {
          final nonce = await _readExactly(handle, _nonceBytes);
          final mac = await _readExactly(handle, _macBytes);
          await cipher.decrypt(
            SecretBox(const [], nonce: nonce, mac: Mac(mac)),
            secretKey: key,
            aad: _sequenceAad(sequence, isFinal: true),
          );
          if ((await handle.read(1)).isNotEmpty) {
            throw const FormatException('Dados extras no arquivo protegido.');
          }
          return;
        }
        if (length <= 0 || length > _streamChunkBytes) {
          throw const FormatException('Bloco inválido no arquivo protegido.');
        }
        final nonce = await _readExactly(handle, _nonceBytes);
        final mac = await _readExactly(handle, _macBytes);
        final encryptedBytes = await _readExactly(handle, length);
        yield await cipher.decrypt(
          SecretBox(encryptedBytes, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: _sequenceAad(sequence++),
        );
        if (sequence % 2 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      await handle.close();
    }
  }

  Future<void> _rekeyChunkedFile(File file,
      {required String currentPassword, required String newPassword}) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${file.path}.rekey-$timestamp');
    final backup = File('${file.path}.rekey-backup-$timestamp');
    try {
      await _writeChunkedFile(
        target: temporary,
        password: newPassword,
        bytes: _decryptedChunkStream(file, currentPassword),
      );
      await file.rename(backup.path);
      await temporary.rename(file.path);
    } catch (_) {
      if (await backup.exists()) {
        if (await File(file.path).exists()) await File(file.path).delete();
        await backup.rename(file.path);
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  Future<bool> _hasStreamFormat(File file) async {
    final handle = await file.open();
    try {
      final prefix = await handle.read(_streamMagic.length);
      return _sameBytes(prefix, _streamMagic);
    } finally {
      await handle.close();
    }
  }

  Future<SecretKey> _deriveContentKey(String password, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _keyIterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  static Uint8List _sequenceAad(int sequence, {bool isFinal = false}) {
    final data = ByteData(5)
      ..setUint8(0, isFinal ? 1 : 0)
      ..setUint32(1, sequence, Endian.big);
    return data.buffer.asUint8List();
  }

  Future<Uint8List> _readExactly(RandomAccessFile handle, int length) async {
    final result = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final part = await handle.read(length - offset);
      if (part.isEmpty) {
        throw const FormatException('Arquivo protegido incompleto.');
      }
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Future<void> _writeAtomically(
    File target,
    Map<String, dynamic> envelope, {
    bool wipePrevious = false,
  }) async {
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.tmp-$uniqueId');
    final backup = File('${target.path}.bak');
    // 1. Gravação com flush garantido
    final handle = await temporary.open(mode: FileMode.writeOnly);
    try {
      await handle.writeString(jsonEncode(envelope));
      await handle.flush();
    } finally {
      await handle.close();
    }
    // 2. Validação da integridade do arquivo gerado
    final length = await temporary.length();
    if (length == 0) {
      if (await temporary.exists()) await temporary.delete();
      throw const FileSystemException(
          'Falha de escrita: arquivo temporário gerado vazio.');
    }
    // 3. Backup de segurança do alvo anterior (se existir)
    if (await backup.exists() &&
        (wipePrevious || await target.exists())) {
      if (wipePrevious) {
        await _secureDelete(backup);
      } else {
        await backup.delete();
      }
    }
    if (await target.exists()) {
      await target.copy(backup.path);
    }
    // 4. Substituição atômica com rollback automático em caso de erro
    try {
      if (await target.exists()) {
        if (wipePrevious) {
          await _secureDelete(target);
        } else {
          await target.delete();
        }
      }
      await temporary.rename(target.path);
    } catch (_) {
      // Rollback
      if (await backup.exists()) {
        if (await target.exists()) await target.delete();
        await backup.rename(target.path);
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    if (await backup.exists()) {
      if (wipePrevious) {
        try {
          await _secureDelete(backup);
        } catch (error) {
          throw _PostCommitCleanupException(error);
        }
      } else {
        await backup.delete();
      }
    }
  }

  void _validateNewPassword(String password) {
    if (password.length < 8) {
      throw const FormatException('A senha deve ter pelo menos 8 caracteres.');
    }
  }

  Future<Directory> _vaultDirectory() async {
    final cached = _cachedVaultDirectory;
    if (cached != null) {
      return cached;
    }
    final directory = Directory(await storageLocation());
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _cachedVaultDirectory = directory;
    return directory;
  }

  Future<void> _secureDelete(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    final handle = await file.open(mode: FileMode.writeOnly);
    try {
      final random = Random.secure();
      final buffer = Uint8List(_wipeChunkBytes);
      var remaining = length;
      while (remaining > 0) {
        final chunkLength = min(buffer.length, remaining);
        for (var i = 0; i < chunkLength; i++) {
          buffer[i] = random.nextInt(256);
        }
        await handle.writeFrom(buffer, 0, chunkLength);
        remaining -= chunkLength;
      }
      await handle.flush();
    } finally {
      await handle.close();
    }
    await file.delete();
  }

  Future<void> _saveIndex(List<SafeItem> items) async {
    final preferences = await _preferences;
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    final record =
        jsonEncode({'payload': payload, 'mac': await _indexMac(payload)});
    await preferences.setString(_indexRecordKey, record);
    await preferences.remove(_indexPayloadKey);
    await preferences.remove(_indexMacKey);
    await preferences.remove(_indexKey);
  }

  Future<String> _indexMac(String payload) async {
    final preferences = await _preferences;
    var encodedSecret = await _readIndexSecret(preferences);
    if (encodedSecret == null) {
      encodedSecret = base64Encode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)));
      await _writeIndexSecret(preferences, encodedSecret);
    }
    final mac = await Hmac.sha256().calculateMac(utf8.encode(payload),
        secretKey: SecretKey(base64Decode(encodedSecret)));
    return base64Encode(mac.bytes);
  }

  Future<String?> _readIndexSecret(SharedPreferences preferences) async {
    if (_cachedIndexSecret != null) return _cachedIndexSecret;
    try {
      final secureValue = await _secureStorage.read(key: _indexSecretKey);
      if (secureValue != null) {
        _cachedIndexSecret = secureValue;
        return secureValue;
      }
    } catch (_) {}
    final prefValue = preferences.getString(_indexSecretKey);
    if (prefValue != null) {
      _cachedIndexSecret = prefValue;
    }
    return prefValue;
  }

  Future<void> _writeIndexSecret(
      SharedPreferences preferences, String value) async {
    _cachedIndexSecret = value;
    try {
      await _secureStorage.write(key: _indexSecretKey, value: value);
      await preferences.remove(_indexSecretKey);
    } catch (_) {
      await preferences.setString(_indexSecretKey, value);
    }
  }

  Future<void> _deleteIndexSecret(SharedPreferences preferences) async {
    _cachedIndexSecret = null;
    try {
      await _secureStorage.delete(key: _indexSecretKey);
    } catch (_) {}
    await preferences.remove(_indexSecretKey);
  }

  List<SafeItem> _decodeItems(String payload) {
    final raw = jsonDecode(payload) as List<dynamic>;
    return _sortItems(
        raw.map((entry) => SafeItem.fromJson(entry as Map<String, dynamic>)));
  }

  List<SafeItem> _sortItems(Iterable<SafeItem> items) {
    return items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class _PostCommitCleanupException implements Exception {
  _PostCommitCleanupException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'O arquivo foi atualizado, mas não foi possível sobrescrever '
      'o backup anterior. Dados antigos ainda podem permanecer no armazenamento '
      '($cause).';
}
