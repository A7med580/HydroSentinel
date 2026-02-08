enum FactoryStatus { good, warning, critical }

class FactoryEntity {
  final String id;
  final String name;
  final String driveFolderId;
  final DateTime? lastSyncAt;
  final FactoryStatus status;
  final double? healthScore;
  final int? alertCount;

  FactoryEntity({
    required this.id,
    required this.name,
    required this.driveFolderId,
    this.lastSyncAt,
    required this.status,
    this.healthScore,
    this.alertCount,
  });

  factory FactoryEntity.fromMap(Map<String, dynamic> map) {
    return FactoryEntity(
      id: map['id'],
      name: map['name'],
      driveFolderId: map['drive_folder_id'],
      lastSyncAt: map['last_sync_at'] != null ? DateTime.parse(map['last_sync_at']) : null,
      status: FactoryStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FactoryStatus.good,
      ),
      healthScore: (map['health_score'] as num?)?.toDouble(),
      alertCount: map['alert_count'] as int?,
    );
  }
}

