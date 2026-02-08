import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/factories/domain/measurement_v2.dart';

class AnalyticsService {
  final SupabaseClient _supabase;

  AnalyticsService(this._supabase);

  /// Aggregates measurements for a specific factory and time range
  /// Returns a map of parameter -> aggregated value
  Future<Map<String, double>> getAggregatedMetrics({
    required String factoryId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> parameters,
  }) async {
    // 1. Fetch all measurements in range
    // Performance Optimization: We fetch only needed columns
    final response = await _supabase
        .from('measurements_v2')
        .select('period_type, start_date, end_date, data')
        .eq('factory_id', factoryId)
        .gte('end_date', startDate.toIso8601String())
        .lte('start_date', endDate.toIso8601String());

    final measurements = (response as List)
        .map((json) => MeasurementV2(
              factoryId: factoryId,
              periodType: PeriodType.values.firstWhere((e) => e.name == json['period_type']),
              startDate: DateTime.parse(json['start_date']),
              endDate: DateTime.parse(json['end_date']),
              data: json['data'] ?? {},
            ))
        .toList();

    // 2. Aggregate per parameter
    final Map<String, double> results = {};
    for (var param in parameters) {
      results[param] = _calculateTimeWeightedAverage(measurements, param, startDate, endDate);
    }
    
    return results;
  }

  /// Calculates Time-Weighted Average (Scientific Precision)
  /// Algorithm:
  /// 1. Create a "Day Map" for the requested range.
  /// 2. For each day, find the "Best Granularity" measurement (Daily > Weekly > Monthly).
  /// 3. Sum values / Count valid days.
  double _calculateTimeWeightedAverage(
    List<MeasurementV2> measurements,
    String paramKey,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    double totalValue = 0.0;
    int validDays = 0;

    // Create lookup maps for fast access
    // Key: YYYY-MM-DD
    final Map<String, double> dailyMap = {};
    final Map<String, double> weeklyMap = {}; // Key: YYYY-MM-DD (for every day in week)
    final Map<String, double> monthlyMap = {}; // Key: YYYY-MM-DD (for every day in month)

    for (var m in measurements) {
      final val = m.data[paramKey];
      if (val == null || val is! num) continue;
      final doubleValue = val.toDouble();

      if (m.periodType == PeriodType.daily) {
        dailyMap[_dateKey(m.startDate)] = doubleValue;
      } else if (m.periodType == PeriodType.weekly) {
        // Expand to days
        _expandToDays(weeklyMap, m.startDate, m.endDate, doubleValue);
      } else if (m.periodType == PeriodType.monthly) {
        _expandToDays(monthlyMap, m.startDate, m.endDate, doubleValue);
      }
    }

    // Iterate through every single day in the requested range
    final days = rangeEnd.difference(rangeStart).inDays + 1;
    for (var i = 0; i < days; i++) {
      final date = rangeStart.add(Duration(days: i));
      final key = _dateKey(date);
      
      double? valueForDay;
      
      // GRANULARITY LADDER
      if (dailyMap.containsKey(key)) {
        valueForDay = dailyMap[key];
      } else if (weeklyMap.containsKey(key)) {
        valueForDay = weeklyMap[key];
      } else if (monthlyMap.containsKey(key)) {
        valueForDay = monthlyMap[key];
      }
      
      if (valueForDay != null) {
        totalValue += valueForDay;
        validDays++;
      }
    }

    if (validDays == 0) return 0.0;
    return totalValue / validDays;
  }

  void _expandToDays(Map<String, double> targetMap, DateTime start, DateTime end, double value) {
    // Safety check: limit expansion to reasonable range (e.g. 366 days)
    final days = end.difference(start).inDays + 1;
    if (days > 400) return; // Prevention against infinite loops or bad data

    for (var i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      targetMap[_dateKey(date)] = value;
    }
  }

  String _dateKey(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }
}
