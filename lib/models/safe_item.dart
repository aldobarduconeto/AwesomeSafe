class SafeItem {
  final String id;
  final String fileName;
  final String mimeType;
  final int byteLength;
  final DateTime createdAt;
  final List<String> shardPaths;

  const SafeItem({required this.id, required this.fileName, required this.mimeType, required this.byteLength, required this.createdAt, this.shardPaths = const []});
  /// Absolute paths to the directories holding each shard file. Empty for legacy (non-sharded) items.

  bool get isImage => mimeType.startsWith('image/');
  bool get isSharded => shardPaths.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'byteLength': byteLength,
        'createdAt': createdAt.toIso8601String(),
        if (shardPaths.isNotEmpty) 'shardPaths': shardPaths,
      };

  factory SafeItem.fromJson(Map<String, dynamic> json) => SafeItem(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        byteLength: json['byteLength'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        shardPaths: (json['shardPaths'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );
}
