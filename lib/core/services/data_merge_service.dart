import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/factories/domain/measurement_v2.dart';

class DataMergeService {
  final SupabaseClient _supabase;

  DataMergeService(this._supabase);

  /// Merges a batch of new measurements into the database
  /// Rules:
  /// 1. Granularity Wins: Daily vs Monthly is handled by PeriodType query
  /// 2. Latest Wins: Overwrites existing records for same Factory + Period + Date
  Future<void> mergeMeasurements(List<MeasurementV2> newMeasurements) async {
    if (newMeasurements.isEmpty) return;

    // 1. Group by Period Type for efficient processing
    final Map<PeriodType, List<MeasurementV2>> grouped = {};
    for (var m in newMeasurements) {
      if (!grouped.containsKey(m.periodType)) {
        grouped[m.periodType] = [];
      }
      grouped[m.periodType]!.add(m);
    }

    // 2. Process each group
    for (var periodType in grouped.keys) {
      await _processGroup(periodType, grouped[periodType]!);
    }
  }

  Future<void> _processGroup(PeriodType periodType, List<MeasurementV2> measurements) async {
    if (measurements.isEmpty) return;
    
    final factoryId = measurements.first.factoryId;
    
    // Chunk size to avoid URL length limits
    const int chunkSize = 100;
    
    // Process in chunks
    for (var i = 0; i < measurements.length; i += chunkSize) {
      final end = (i + chunkSize < measurements.length) ? i + chunkSize : measurements.length;
      final chunk = measurements.sublist(i, end);
      
      final dates = chunk.map((m) => m.startDate.toIso8601String().substring(0, 10)).toList();
      final records = chunk.map((m) => m.toJson()).toList();
      
      try {
        // 1. Delete existing collisions (Latest Wins Rule)
        await _supabase.from('measurements_v2')
            .delete()
            .eq('factory_id', factoryId)
            .eq('period_type', periodType.name)
            .filter('start_date', 'in', '(${dates.join(',')})');
            
        // 2. Insert New
        await _supabase.from('measurements_v2').insert(records);
        
        print('Merged ${chunk.length} ${periodType.name} records for factory $factoryId');
      } catch (e) {
        print('Error merging chunk for $periodType: $e');
        // Continue with next chunk or rethrow?
        // Rethrowing is safer to alert user of partial failure
        rethrow;
      }
    }
  }
}
