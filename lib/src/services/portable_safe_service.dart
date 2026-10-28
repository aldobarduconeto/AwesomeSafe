import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'vault_key_derivation.dart';

class PortableSafeFile {
  const PortableSafeFile(this.fileName, this.mimeType, this.bytes);
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

/// A self-contained, authenticated envelope, independent of the local index.
class PortableSafeService {
  static const _format = 'awesome_safe_portable';
  static final _aad = utf8.encode('awesome_safe_portable:1');

  static Future<Uint8List> encrypt(PortableSafeFile file, String password) =>
      Isolate.run(() async {
        if (password.length < 8) {
          throw const FormatException(
              'A senha deve ter pelo menos 8 caracteres.');
        }
        final random = Random.secure();
        final salt = List<int>.generate(16, (_) => random.nextInt(256));
        final key = SecretKey(await deriveVaultKeyBytes(password, salt));
        final payload = utf8.encode(jsonEncode({
          'fileName': file.fileName,
          'mimeType': file.mimeType,
          'data': base64Encode(file.bytes),
        }));
        final box = await AesGcm.with256bits().encrypt(
          payload,
          secretKey: key,
          aad: _aad,
        );
        return Uint8List.fromList(utf8.encode(jsonEncode({
          'format': _format,
          'version': 1,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'cipherText': base64Encode(box.cipherText),
        })));
      });

  static Future<PortableSafeFile> decrypt(Uint8List bytes, String password) =>
      Isolate.run(() async {
        try {
          final envelope =
              jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          if (envelope['format'] != _format || envelope['version'] != 1) {
            throw const FormatException();
          }
          final salt = base64Decode(envelope['salt'] as String);
          final nonce = base64Decode(envelope['nonce'] as String);
          final mac = base64Decode(envelope['mac'] as String);
          if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
            throw const FormatException();
          }
          final key = SecretKey(await deriveVaultKeyBytes(password, salt));
          final plain = await AesGcm.with256bits().decrypt(
            SecretBox(base64Decode(envelope['cipherText'] as String),
                nonce: nonce, mac: Mac(mac)),
            secretKey: key,
            aad: _aad,
          );
          final payload =
              jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
          final name = payload['fileName'] as String;
          final mime = payload['mimeType'] as String;
          if (name.trim().isEmpty ||
              name == '.' ||
              name == '..' ||
              name.contains(RegExp(r'[/\\\x00-\x1f]')) ||
              !RegExp(r'^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$')
                  .hasMatch(mime)) {
            throw const FormatException();
          }
          return PortableSafeFile(
              name, mime, base64Decode(payload['data'] as String));
        } catch (_) {
          throw const FormatException(
              'Senha incorreta, arquivo danificado ou formato .safe não portátil.');
        }
      });
}
