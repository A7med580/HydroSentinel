import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chemistry_models.dart';
import '../models/assessment_models.dart';
import 'calculation_engine.dart';
import '../core/widgets/period_selector.dart';
import '../features/factories/domain/measurement_v2.dart';

/// Notifier for selected factory ID
class SelectedFactoryIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setFactoryId(String? id) => state = id;
}

/// Notifier for selected time period  
class SelectedPeriodNotifier extends Notifier<TimePeriod> {
  @override
  TimePeriod build() => TimePeriod.week;
  
  void setPeriod(TimePeriod period) => state = period;
}

/// Provider for the currently selected factory ID
final selectedFactoryIdProvider = NotifierProvider<SelectedFactoryIdNotifier, String?>(() {
  return SelectedFactoryIdNotifier();
});

/// Provider for the currently selected time period
final selectedPeriodProvider = NotifierProvider<SelectedPeriodNotifier, TimePeriod>(() {
  return SelectedPeriodNotifier();
});

/// Main provider that fetches and aggregates all measurements
final aggregatedDataProvider = FutureProvider<AggregatedData?>((ref) async {
  final factoryId = ref.watch(selectedFactoryIdProvider);
  final period = ref.watch(selectedPeriodProvider);
  
  if (factoryId == null) {
    // If no factory selected, try to get first factory
    final factories = await Supabase.instance.client
        .from('factories')
        .select('id')
        .limit(1);
    
    if (factories.isEmpty) return null;
    
    // Use the first factory as default
    final defaultFactoryId = factories[0]['id'] as String;
    return _fetchAggregatedData(defaultFactoryId, period);
  }
  
  return _fetchAggregatedData(factoryId, period);
});

/// Fetches and aggregates measurements for a factory and period
Future<AggregatedData?> _fetchAggregatedData(String factoryId, TimePeriod period) async {
  final supabase = Supabase.instance.client;
  
  // Calculate date range based on period
  final now = DateTime.now();
  DateTime startDate;
  
  switch (period) {
    case TimePeriod.day:
      startDate = DateTime(now.year, now.month, now.day);
      break;
    case TimePeriod.week:
      startDate = now.subtract(const Duration(days: 7));
      break;
    case TimePeriod.month:
      startDate = DateTime(now.year, now.month - 1, now.day);
      break;
    case TimePeriod.year:
      startDate = DateTime(now.year - 1, now.month, now.day);
      break;
  }
  
  // Fetch all measurements in range
  final response = await supabase
      .from('measurements_v2')
      .select('*')
      .eq('factory_id', factoryId)
      .gte('start_date', startDate.toIso8601String())
      .lte('end_date', now.toIso8601String())
      .order('start_date', ascending: true);
  
  final measurements = (response as List)
      .map((json) => MeasurementV2(
            factoryId: factoryId,
            periodType: PeriodType.values.firstWhere(
              (e) => e.name == json['period_type'],
              orElse: () => PeriodType.daily,
            ),
            startDate: DateTime.parse(json['start_date']),
            endDate: DateTime.parse(json['end_date']),
            data: json['data'] ?? {},
            indices: json['indices'],
          ))
      .toList();
  
  print('DEBUG: [Aggregation] Found ${measurements.length} measurements for period ${period.name}');
  
  if (measurements.isEmpty) {
    return null;
  }
  
  // Aggregate ALL measurements
  final aggregated = _calculateAggregates(measurements);
  
  // Calculate indices and risks from aggregated data
  final ctData = CoolingTowerData(
    ph: WaterParameter(
      name: 'pH', 
      value: aggregated['ph'] ?? 0, 
      unit: 'pH',
      optimalMin: 7.0, 
      optimalMax: 8.5,
      quality: CalculationEngine.validateParameter(aggregated['ph'] ?? 0, 7.0, 8.5),
    ),
    alkalinity: WaterParameter(
      name: 'Alkalinity',
      value: aggregated['alkalinity'] ?? 0,
      unit: 'ppm',
      optimalMin: 100,
      optimalMax: 500,
      quality: CalculationEngine.validateParameter(aggregated['alkalinity'] ?? 0, 100, 500),
    ),
    conductivity: WaterParameter(
      name: 'Conductivity',
      value: aggregated['conductivity'] ?? 0,
      unit: 'µS/cm',
      optimalMin: 500,
      optimalMax: 3000,
      quality: CalculationEngine.validateParameter(aggregated['conductivity'] ?? 0, 500, 3000),
    ),
    totalHardness: WaterParameter(
      name: 'Total Hardness',
      value: aggregated['hardness'] ?? 0,
      unit: 'ppm',
      optimalMin: 50,
      optimalMax: 400,
      quality: CalculationEngine.validateParameter(aggregated['hardness'] ?? 0, 50, 400),
    ),
    chloride: WaterParameter(
      name: 'Chloride',
      value: aggregated['chloride'] ?? 0,
      unit: 'ppm',
      optimalMin: 0,
      optimalMax: 250,
      quality: CalculationEngine.validateParameter(aggregated['chloride'] ?? 0, 0, 250),
    ),
    zinc: WaterParameter(
      name: 'Zinc',
      value: aggregated['zinc'] ?? 0,
      unit: 'ppm',
      optimalMin: 0.5,
      optimalMax: 2.0,
      quality: CalculationEngine.validateParameter(aggregated['zinc'] ?? 0, 0.5, 2.0),
    ),
    iron: WaterParameter(
      name: 'Iron',
      value: aggregated['iron'] ?? 0,
      unit: 'ppm',
      optimalMin: 0,
      optimalMax: 0.5,
      quality: CalculationEngine.validateParameter(aggregated['iron'] ?? 0, 0, 0.5),
    ),
    phosphates: WaterParameter(
      name: 'Phosphates',
      value: aggregated['phosphates'] ?? 0,
      unit: 'ppm',
      optimalMin: 5,
      optimalMax: 15,
      quality: CalculationEngine.validateParameter(aggregated['phosphates'] ?? 0, 5, 15),
    ),
    timestamp: DateTime.now(),
  );
  
  // RO Data if available
  ROData? roData;
  if (aggregated['free_chlorine'] != null || aggregated['silica'] != null) {
    roData = ROData(
      freeChlorine: WaterParameter(
        name: 'Free Chlorine',
        value: aggregated['free_chlorine'] ?? 0,
        unit: 'ppm',
        optimalMin: 0,
        optimalMax: 0.1,
        quality: CalculationEngine.validateParameter(aggregated['free_chlorine'] ?? 0, 0, 0.1),
      ),
      silica: WaterParameter(
        name: 'Silica',
        value: aggregated['silica'] ?? 0,
        unit: 'ppm',
        optimalMin: 0,
        optimalMax: 150,
        quality: CalculationEngine.validateParameter(aggregated['silica'] ?? 0, 0, 150),
      ),
      roConductivity: WaterParameter(
        name: 'RO Conductivity',
        value: aggregated['ro_conductivity'] ?? 0,
        unit: 'µS/cm',
        optimalMin: 0,
        optimalMax: 50,
        quality: CalculationEngine.validateParameter(aggregated['ro_conductivity'] ?? 0, 0, 50),
      ),
      timestamp: DateTime.now(),
    );
  }
  
  // Calculate derived metrics
  final indices = CalculationEngine.calculateIndices(ctData);
  final risk = CalculationEngine.assessRisk(indices, ctData);
  final roAssessment = roData != null ? CalculationEngine.assessRO(roData) : null;
  final health = CalculationEngine.calculateHealth(risk, roAssessment);
  final recommendations = CalculationEngine.generateRecommendations(risk, health, roData);
  
  return AggregatedData(
    ctData: ctData,
    roData: roData,
    indices: indices,
    risk: risk,
    roAssessment: roAssessment,
    health: health,
    recommendations: recommendations,
    measurementCount: measurements.length,
    dateRange: DateRange(startDate, DateTime.now()),
    period: period,
    rawMeasurements: measurements,
  );
}

/// Calculate averages for all parameters across measurements
Map<String, double> _calculateAggregates(List<MeasurementV2> measurements) {
  final Map<String, List<double>> values = {};
  
  for (final m in measurements) {
    m.data.forEach((key, value) {
      if (value is num) {
        values.putIfAbsent(key, () => []).add(value.toDouble());
      }
    });
  }
  
  // Calculate averages
  final Map<String, double> averages = {};
  values.forEach((key, list) {
    if (list.isNotEmpty) {
      final sum = list.reduce((a, b) => a + b);
      averages[key] = sum / list.length;
      print('DEBUG: [Aggregate] $key: avg=${averages[key]!.toStringAsFixed(2)} from ${list.length} values');
    }
  });
  
  return averages;
}

/// Holds all aggregated and calculated data
class AggregatedData {
  final CoolingTowerData ctData;
  final ROData? roData;
  final CalculatedIndices indices;
  final RiskAssessment risk;
  final ROProtectionAssessment? roAssessment;
  final SystemHealth health;
  final List<Recommendation> recommendations;
  final int measurementCount;
  final DateRange dateRange;
  final TimePeriod period;
  final List<MeasurementV2> rawMeasurements;
  
  const AggregatedData({
    required this.ctData,
    this.roData,
    required this.indices,
    required this.risk,
    this.roAssessment,
    required this.health,
    required this.recommendations,
    required this.measurementCount,
    required this.dateRange,
    required this.period,
    required this.rawMeasurements,
  });
}

/// Simple date range holder
class DateRange {
  final DateTime start;
  final DateTime end;
  
  const DateRange(this.start, this.end);
  
  int get dayCount => end.difference(start).inDays + 1;
}
