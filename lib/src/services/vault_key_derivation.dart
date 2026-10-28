import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Keep the expensive password derivation off the UI isolate. Only plain data
/// crosses the isolate boundary; streams and platform services stay with callers.
Future<SecretKey> deriveVaultKey(String password, List<int> salt) async {
  final bytes = await Isolate.run(() => deriveVaultKeyBytes(password, salt));
  return SecretKey(bytes);
}

/// Runs in a worker, where event-loop pauses only slow down derivation.
Future<Uint8List> deriveVaultKeyBytes(String password, List<int> salt) async {
  final key = await DartPbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 1000000,
    bits: 256,
    pauseFrequency: 0,
  ).deriveKeyFromPassword(password: password, nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
}
