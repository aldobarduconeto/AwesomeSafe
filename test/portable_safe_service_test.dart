import 'dart:convert';
import 'dart:typed_data';

import 'package:awesome_safe/src/services/portable_safe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portable file opens with password without a local vault', () async {
    final source = PortableSafeFile('ação.txt', 'text/plain',
        Uint8List.fromList(utf8.encode('Conteúdo confidencial')));
    final encrypted =
        await PortableSafeService.encrypt(source, 'Senha-ação-123');
    expect(utf8.decode(encrypted), isNot(contains(source.fileName)));
    expect(utf8.decode(encrypted), isNot(contains('Conteúdo confidencial')));
    final opened =
        await PortableSafeService.decrypt(encrypted, 'Senha-ação-123');
    expect(opened.fileName, source.fileName);
    expect(opened.mimeType, source.mimeType);
    expect(opened.bytes, source.bytes);
    await expectLater(PortableSafeService.decrypt(encrypted, 'senha errada'),
        throwsFormatException);
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final cipher = base64Decode(envelope['cipherText'] as String);
    cipher[0] ^= 1;
    envelope['cipherText'] = base64Encode(cipher);
    await expectLater(
        PortableSafeService.decrypt(
            Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
            'Senha-ação-123'),
        throwsFormatException);
  });

  test('rejects unsupported versions and malformed files', () async {
    for (final input in [
      'invalid',
      '{"format":"awesome_safe_portable","version":2}'
    ]) {
      await expectLater(
          PortableSafeService.decrypt(
              Uint8List.fromList(utf8.encode(input)), 'password123'),
          throwsFormatException);
    }
  });
}
