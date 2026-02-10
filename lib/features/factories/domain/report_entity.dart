class ReportEntity {
  final String id;
  final String factoryId;
  final String? fileId; // Nullable as legacy reports might not have it
  final String fileName;
  final DateTime analyzedAt;
  final Map<String, dynamic> data;

  ReportEntity({
    required this.id,
    required this.factoryId,
    this.fileId,
    required this.fileName,
    required this.analyzedAt,
    required this.data,
  });

  factory ReportEntity.fromMap(Map<String, dynamic> map) {
    return ReportEntity(
      id: map['id'],
      factoryId: map['factory_id'],
      fileId: map['file_id'],
      fileName: map['file_name'],
      analyzedAt: DateTime.parse(map['analyzed_at']),
      data: map['data'],
    );
  }
}
