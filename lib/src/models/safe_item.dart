class SafeItem {
  final String id;
  final String fileName;
  final String mimeType;
  final int byteLength;
  final DateTime createdAt;

  const SafeItem(
      {required this.id,
      required this.fileName,
      required this.mimeType,
      required this.byteLength,
      required this.createdAt});

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toJson() => {
        'id': id,
        'byteLength': byteLength,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SafeItem.fromJson(Map<String, dynamic> json) => SafeItem(
        id: json['id'] as String,
        fileName: json['fileName'] as String? ?? 'arquivo criptografado',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        byteLength: json['byteLength'] as int? ?? 0,
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      );
}
