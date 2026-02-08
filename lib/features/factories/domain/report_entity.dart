class ReportEntity {
  final String id;
  final String factoryId;
  final String fileName;
  final DateTime analyzedAt;
  final Map<String, dynamic> data;

  ReportEntity({
    required this.id,
    required this.factoryId,
    required this.fileName,
    required this.analyzedAt,
    required this.data,
  });

  factory ReportEntity.fromMap(Map<String, dynamic> map) {
    return ReportEntity(
      id: map['id'],
      factoryId: map['factory_id'],
      fileName: map['file_name'],
      analyzedAt: DateTime.parse(map['analyzed_at']),
      data: map['data'],
    );
  }
}
