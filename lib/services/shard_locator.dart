import 'dart:io';
import 'dart:math';

/// Finds and manages scatter directories across the filesystem.
/// On Windows, fragments are placed in short random-named directories at the
/// root of each available drive (e.g. C:\a3f8b2\). If no drive root is
/// writable, falls back to a random subdirectory of %LOCALAPPDATA%.
class ShardLocator {
  static const _minDirs = 3;
  static const _maxDirs = 7;
  final _random = Random.secure();

  /// Returns [count] distinct writable directories to scatter shards into.
  /// Each directory is created if it does not exist.
  Future<List<String>> pickScatterDirs(int count) async {
    final candidates = await _candidateRoots();
    final dirs = <String>[];
    final tried = <String>{};

    while (dirs.length < count && candidates.isNotEmpty) {
      final root = candidates[_random.nextInt(candidates.length)];
      final name = _randomHex(6);
      final path = '$root$name';
      if (tried.contains(path)) continue;
      tried.add(path);
      try {
        final dir = Directory(path);
        await dir.create(recursive: true);
        dirs.add(path);
      } catch (_) {candidates.remove(root);}
    }
    if (dirs.length < count) { throw StateError('Não foi possível encontrar $count diretórios graváveis para dispersão.');}
    return dirs;
  }

  /// Removes a shard directory (used during delete).
  Future<void> removeDir(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {await dir.delete(recursive: true);}
  }

  int get randomShardCount => _minDirs + _random.nextInt(_maxDirs - _minDirs + 1);
  // ── internals ─────────────────────────────────────────────────────────────
  Future<List<String>> _candidateRoots() async {
    if (!Platform.isWindows) {return ['/tmp/'];}
    final roots = <String>[];
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
      final drive = '${String.fromCharCode(c)}:\\';
      if (await Directory(drive).exists()) {roots.add(drive);}
    }
    if (roots.isEmpty) {
      final local = Platform.environment['LOCALAPPDATA'] ?? '${Platform.environment['USERPROFILE']}\\AppData\\Local';
      roots.add('$local\\');
    }
    return roots;
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
