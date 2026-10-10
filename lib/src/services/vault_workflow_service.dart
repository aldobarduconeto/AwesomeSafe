import 'vault_service.dart';
import '../models/safe_item.dart';
import 'package:file_picker/file_picker.dart';

class VaultWorkflowService {
  VaultWorkflowService(this._vaultService);
  static final _uppercase = RegExp(r'[A-Z]');
  static final _lowercase = RegExp(r'[a-z]');
  static final _digits = RegExp(r'[0-9]');

  static const mimeTypeOptions = <String, String>{
    'Texto simples': 'text/plain',
    'PDF': 'application/pdf',
    'Imagem PNG': 'image/png',
    'Imagem JPEG': 'image/jpeg',
    'Imagem GIF': 'image/gif',
    'Imagem WebP': 'image/webp',
    'Áudio MP3': 'audio/mpeg',
    'Vídeo MP4': 'video/mp4',
    'Outro (informar MIME)': 'custom',
  };

  static const _extensionMimeTypes = {
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
  };

  final VaultService _vaultService;

  Future<String?> importSelectedFile({
    required String password,
    required Future<String?> Function(String? suggestedMimeType) chooseMimeType,
  }) async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final mimeType = await chooseMimeType(mimeTypeForExtension(file.extension));
    if (mimeType == null) return null;
    await _vaultService.saveFileStream(
      password: password,
      fileName: file.name,
      mimeType: mimeType,
      bytes: file.readAsByteStream(),
    );
    return file.name;
  }

  Future<void> exportItem(
      {required String password, required SafeItem item}) async {
    final bytes = await _vaultService.readFile(password: password, item: item);
    await FilePicker.saveFile(
      fileName: item.fileName,
      bytes: bytes,
      mimeType: item.mimeType,
    );
  }

  Future<String?> chooseStorageDirectory() => FilePicker.getDirectoryPath(
      dialogTitle: 'Escolha o drive ou pasta do cofre');

  static String mimeTypeForExtension(String? extension) =>
      _extensionMimeTypes[extension?.toLowerCase()] ??
      'application/octet-stream';

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String passwordHint(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (_uppercase.hasMatch(password)) score++;
    if (_lowercase.hasMatch(password)) score++;
    if (_digits.hasMatch(password)) score++;
    if (score <= 1) return 'Senha fraca: use pelo menos 8 caracteres.';
    if (score == 2) {
      return 'Senha razoável: misture letras, números e símbolos.';
    }
    return 'Senha forte.';
  }
}
