class ContainerData {
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> files;
  ContainerData({required this.version,required this.createdAt,required this.updatedAt,required this.files});
  Map<String, dynamic> toJson() => {'version': version, 'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(), 'files': files};
  factory ContainerData.fromJson(Map<String, dynamic> json) => ContainerData(
        version: json['version'] as int? ?? 1,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
        files: (json['files'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[],
      );
}
