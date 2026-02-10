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

/// Fetches measurements and calculates DAILY scores first, then averages those scores
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
      startDate = now.subtract(const Duration(days: 30));
      break;
    case TimePeriod.year:
      startDate = now.subtract(const Duration(days: 365));
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
  
  // =====================================================
  // CORRECT LOGIC: Calculate score PER DAY, then average
  // =====================================================
  
  List<DailyCalculation> dailyCalculations = [];
  
  for (final m in measurements) {
    // Build CoolingTowerData for THIS day's measurement
    final ctData = _buildCTDataFromMeasurement(m);
    
    // Calculate indices for THIS day
    final indices = CalculationEngine.calculateIndices(ctData);
    
    // Calculate risk for THIS day (pass roData for silica fouling — Task 1.4)
    ROData? roData = _buildRODataFromMeasurement(m);
    final risk = CalculationEngine.assessRisk(indices, ctData, roData: roData);
    
    // Build RO assessment
    ROProtectionAssessment? roAssessment = roData != null 
        ? CalculationEngine.assessRO(roData) 
        : null;
    
    // Calculate health for THIS day (Task 1.5: pass ctData for treatment score)
    final health = CalculationEngine.calculateHealth(risk, roAssessment, ctData: ctData, roData: roData);
    
    dailyCalculations.add(DailyCalculation(
      date: m.startDate,
      ctData: ctData,
      roData: roData,
      indices: indices,
      risk: risk,
      roAssessment: roAssessment,
      health: health,
    ));
    
    print('DEBUG: [Day ${m.startDate.day}] Health=${health.overallScore.toStringAsFixed(1)}, Scaling=${risk.scalingScore.toStringAsFixed(1)}, Corrosion=${risk.corrosionScore.toStringAsFixed(1)}');
  }
  
  // =====================================================
  // Now AVERAGE the daily scores
  // =====================================================
  
  final avgHealth = _averageHealth(dailyCalculations);
  final avgRisk = _averageRisk(dailyCalculations);
  final avgIndices = _averageIndices(dailyCalculations);
  final avgCtData = _averageCtData(dailyCalculations);
  final avgRoData = _averageRoData(dailyCalculations);
  final avgRoAssessment = _averageRoAssessment(dailyCalculations);
  
  // Collect historical pH and conductivity for stability scoring (Task 1.5)
  final historicalPh = dailyCalculations.map((d) => d.ctData.ph.value).toList();
  final historicalCond = dailyCalculations.map((d) => d.ctData.conductivity.value).toList();
  
  // Re-calculate average health WITH stability data
  final avgHealthWithStability = CalculationEngine.calculateHealth(
    avgRisk, avgRoAssessment,
    ctData: avgCtData, roData: avgRoData,
    historicalPh: historicalPh, historicalConductivity: historicalCond,
  );
  
  // Generate recommendations based on AVERAGE risk
  final recommendations = CalculationEngine.generateRecommendations(avgRisk, avgHealthWithStability, avgRoData, ctData: avgCtData, indices: avgIndices);
  
  print('DEBUG: [Period ${period.name}] Avg Health=${avgHealth.overallScore.toStringAsFixed(1)} from ${dailyCalculations.length} days');
  
  return AggregatedData(
    ctData: avgCtData,
    roData: avgRoData,
    indices: avgIndices,
    risk: avgRisk,
    roAssessment: avgRoAssessment,
    health: avgHealthWithStability,
    recommendations: recommendations,
    measurementCount: dailyCalculations.length,
    dateRange: DateRange(startDate, DateTime.now()),
    period: period,
    rawMeasurements: measurements,
    dailyCalculations: dailyCalculations,
  );
}

/// Build CoolingTowerData from a single measurement
CoolingTowerData _buildCTDataFromMeasurement(MeasurementV2 m) {
  double val(String key) {
    final v = m.data[key];
    if (v is num) return v.toDouble();
    return 0.0;
  }
  
  // Build optional temperature and sulfate from measurement data
  WaterParameter? tempParam;
  final tempVal = m.data['temperature'];
  if (tempVal is num && tempVal > 0) {
    tempParam = WaterParameter(name: 'Temperature', value: tempVal.toDouble(), unit: '°C', optimalMin: 20, optimalMax: 45);
  }
  WaterParameter? sulfateParam;
  final sulfateVal = m.data['sulfate'];
  if (sulfateVal is num && sulfateVal > 0) {
    sulfateParam = WaterParameter(name: 'Sulfate', value: sulfateVal.toDouble(), unit: 'ppm', optimalMin: 0, optimalMax: 500);
  }

  return CoolingTowerData(
    ph: WaterParameter(
      name: 'pH', value: val('ph'), unit: 'pH',
      optimalMin: 7.0, optimalMax: 8.5,
      quality: CalculationEngine.validateParameter(val('ph'), 7.0, 8.5),
    ),
    alkalinity: WaterParameter(
      name: 'Alkalinity', value: val('alkalinity'), unit: 'ppm',
      optimalMin: 100, optimalMax: 500,
      quality: CalculationEngine.validateParameter(val('alkalinity'), 100, 500),
    ),
    conductivity: WaterParameter(
      name: 'Conductivity', value: val('conductivity'), unit: 'µS/cm',
      optimalMin: 500, optimalMax: 3000,
      quality: CalculationEngine.validateParameter(val('conductivity'), 500, 3000),
    ),
    totalHardness: WaterParameter(
      name: 'Total Hardness', value: val('hardness'), unit: 'ppm',
      optimalMin: 50, optimalMax: 400,
      quality: CalculationEngine.validateParameter(val('hardness'), 50, 400),
    ),
    chloride: WaterParameter(
      name: 'Chloride', value: val('chloride'), unit: 'ppm',
      optimalMin: 0, optimalMax: 250,
      quality: CalculationEngine.validateParameter(val('chloride'), 0, 250),
    ),
    zinc: WaterParameter(
      name: 'Zinc', value: val('zinc'), unit: 'ppm',
      optimalMin: 0.5, optimalMax: 2.0,
      quality: CalculationEngine.validateParameter(val('zinc'), 0.5, 2.0),
    ),
    iron: WaterParameter(
      name: 'Iron', value: val('iron'), unit: 'ppm',
      optimalMin: 0, optimalMax: 0.5,
      quality: CalculationEngine.validateParameter(val('iron'), 0, 0.5),
    ),
    phosphates: WaterParameter(
      name: 'Phosphates', value: val('phosphates'), unit: 'ppm',
      optimalMin: 5, optimalMax: 15,
      quality: CalculationEngine.validateParameter(val('phosphates'), 5, 15),
    ),
    temperature: tempParam,
    sulfate: sulfateParam,
    timestamp: m.startDate,
  );
}

/// Build ROData from a single measurement (if RO params exist)
ROData? _buildRODataFromMeasurement(MeasurementV2 m) {
  final fc = m.data['free_chlorine'];
  final si = m.data['silica'];
  final rc = m.data['ro_conductivity'];
  
  if (fc == null && si == null && rc == null) return null;
  
  double val(String key) {
    final v = m.data[key];
    if (v is num) return v.toDouble();
    return 0.0;
  }
  
  return ROData(
    freeChlorine: WaterParameter(
      name: 'Free Chlorine', value: val('free_chlorine'), unit: 'ppm',
      optimalMin: 0, optimalMax: 0.1,
      quality: CalculationEngine.validateParameter(val('free_chlorine'), 0, 0.1),
    ),
    silica: WaterParameter(
      name: 'Silica', value: val('silica'), unit: 'ppm',
      optimalMin: 0, optimalMax: 150,
      quality: CalculationEngine.validateParameter(val('silica'), 0, 150),
    ),
    roConductivity: WaterParameter(
      name: 'RO Conductivity', value: val('ro_conductivity'), unit: 'µS/cm',
      optimalMin: 0, optimalMax: 50,
      quality: CalculationEngine.validateParameter(val('ro_conductivity'), 0, 50),
    ),
    timestamp: m.startDate,
  );
}

/// Average daily health scores
SystemHealth _averageHealth(List<DailyCalculation> days) {
  if (days.isEmpty) {
    return SystemHealth(overallScore: 0, status: 'Unknown', keyIssues: []);
  }
  
  double avgScore = days.map((d) => d.health.overallScore).reduce((a, b) => a + b) / days.length;
  
  // Count issues across all days
  Map<String, int> issueCounts = {};
  for (var d in days) {
    for (var issue in d.health.keyIssues) {
      issueCounts[issue] = (issueCounts[issue] ?? 0) + 1;
    }
  }
  
  // Only include issues that appeared in >50% of days
  List<String> significantIssues = issueCounts.entries
      .where((e) => e.value > days.length / 2)
      .map((e) => e.key)
      .toList();
  
  String status;
  if (avgScore > 85) status = "Excellent";
  else if (avgScore > 70) status = "Good";
  else if (avgScore > 50) status = "Fair";
  else if (avgScore > 30) status = "Poor";
  else status = "Critical";
  
  return SystemHealth(
    overallScore: avgScore,
    status: status,
    keyIssues: significantIssues,
  );
}

/// Average daily risk assessments
RiskAssessment _averageRisk(List<DailyCalculation> days) {
  if (days.isEmpty) {
    return RiskAssessment(
      scalingScore: 0, corrosionScore: 0, foulingScore: 0,
      scalingRisk: RiskLevel.low, corrosionRisk: RiskLevel.low, foulingRisk: RiskLevel.low,
      timestamp: DateTime.now(),
    );
  }
  
  double avgScaling = days.map((d) => d.risk.scalingScore).reduce((a, b) => a + b) / days.length;
  double avgCorrosion = days.map((d) => d.risk.corrosionScore).reduce((a, b) => a + b) / days.length;
  double avgFouling = days.map((d) => d.risk.foulingScore).reduce((a, b) => a + b) / days.length;
  
  return RiskAssessment(
    scalingScore: avgScaling,
    corrosionScore: avgCorrosion,
    foulingScore: avgFouling,
    scalingRisk: _getRiskLevel(avgScaling),
    corrosionRisk: _getRiskLevel(avgCorrosion),
    foulingRisk: _getRiskLevel(avgFouling),
    timestamp: DateTime.now(),
  );
}

RiskLevel _getRiskLevel(double score) {
  if (score < 20) return RiskLevel.low;
  if (score < 50) return RiskLevel.medium;
  if (score < 80) return RiskLevel.high;
  return RiskLevel.critical;
}

/// Average daily indices (handles nullable stiffDavis and larsonSkold)
CalculatedIndices _averageIndices(List<DailyCalculation> days) {
  if (days.isEmpty) {
    return CalculatedIndices(
      lsi: 0, rsi: 0, psi: 0,
      coc: 0, adjustedPsi: 0, tdsEstimation: 0, chlorideSulfateRatio: 0,
      usedTemperature: 35.0, sulfateEstimated: true,
      timestamp: DateTime.now(),
    );
  }
  
  double avg(double Function(DailyCalculation) selector) =>
      days.map(selector).reduce((a, b) => a + b) / days.length;
  
  // Nullable averages: only average days where value exists
  double? avgNullable(double? Function(DailyCalculation) selector) {
    final values = days.map(selector).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
  
  return CalculatedIndices(
    lsi: avg((d) => d.indices.lsi),
    rsi: avg((d) => d.indices.rsi),
    psi: avg((d) => d.indices.psi),
    stiffDavis: avgNullable((d) => d.indices.stiffDavis),
    larsonSkold: avgNullable((d) => d.indices.larsonSkold),
    coc: avg((d) => d.indices.coc),
    adjustedPsi: avg((d) => d.indices.adjustedPsi),
    tdsEstimation: avg((d) => d.indices.tdsEstimation),
    chlorideSulfateRatio: avg((d) => d.indices.chlorideSulfateRatio),
    usedTemperature: avg((d) => d.indices.usedTemperature),
    sulfateEstimated: days.any((d) => d.indices.sulfateEstimated),
    timestamp: DateTime.now(),
  );
}

/// Average CT data (for display purposes)
CoolingTowerData _averageCtData(List<DailyCalculation> days) {
  if (days.isEmpty) {
    // Return safe default values instead of crashing
    return CoolingTowerData(
      ph: WaterParameter(name: 'pH', value: 0, unit: 'pH', optimalMin: 7.0, optimalMax: 8.5),
      alkalinity: WaterParameter(name: 'Alkalinity', value: 0, unit: 'ppm', optimalMin: 100, optimalMax: 500),
      conductivity: WaterParameter(name: 'Conductivity', value: 0, unit: 'µS/cm', optimalMin: 500, optimalMax: 3000),
      totalHardness: WaterParameter(name: 'Total Hardness', value: 0, unit: 'ppm', optimalMin: 50, optimalMax: 400),
      chloride: WaterParameter(name: 'Chloride', value: 0, unit: 'ppm', optimalMin: 0, optimalMax: 250),
      zinc: WaterParameter(name: 'Zinc', value: 0, unit: 'ppm', optimalMin: 0.5, optimalMax: 2.0),
      iron: WaterParameter(name: 'Iron', value: 0, unit: 'ppm', optimalMin: 0, optimalMax: 0.5),
      phosphates: WaterParameter(name: 'Phosphates', value: 0, unit: 'ppm', optimalMin: 5, optimalMax: 15),
      timestamp: DateTime.now(),
    );
  }
  
  double avg(double Function(DailyCalculation) selector) =>
      days.map(selector).reduce((a, b) => a + b) / days.length;
  
  return CoolingTowerData(
    ph: WaterParameter(name: 'pH', value: avg((d) => d.ctData.ph.value), unit: 'pH', optimalMin: 7.0, optimalMax: 8.5),
    alkalinity: WaterParameter(name: 'Alkalinity', value: avg((d) => d.ctData.alkalinity.value), unit: 'ppm', optimalMin: 100, optimalMax: 500),
    conductivity: WaterParameter(name: 'Conductivity', value: avg((d) => d.ctData.conductivity.value), unit: 'µS/cm', optimalMin: 500, optimalMax: 3000),
    totalHardness: WaterParameter(name: 'Total Hardness', value: avg((d) => d.ctData.totalHardness.value), unit: 'ppm', optimalMin: 50, optimalMax: 400),
    chloride: WaterParameter(name: 'Chloride', value: avg((d) => d.ctData.chloride.value), unit: 'ppm', optimalMin: 0, optimalMax: 250),
    zinc: WaterParameter(name: 'Zinc', value: avg((d) => d.ctData.zinc.value), unit: 'ppm', optimalMin: 0.5, optimalMax: 2.0),
    iron: WaterParameter(name: 'Iron', value: avg((d) => d.ctData.iron.value), unit: 'ppm', optimalMin: 0, optimalMax: 0.5),
    phosphates: WaterParameter(name: 'Phosphates', value: avg((d) => d.ctData.phosphates.value), unit: 'ppm', optimalMin: 5, optimalMax: 15),
    timestamp: DateTime.now(),
  );
}

/// Average RO data (if any days have it)
ROData? _averageRoData(List<DailyCalculation> days) {
  final daysWithRo = days.where((d) => d.roData != null).toList();
  if (daysWithRo.isEmpty) return null;
  
  double avg(double Function(DailyCalculation) selector) =>
      daysWithRo.map(selector).reduce((a, b) => a + b) / daysWithRo.length;
  
  return ROData(
    freeChlorine: WaterParameter(name: 'Free Chlorine', value: avg((d) => d.roData!.freeChlorine.value), unit: 'ppm', optimalMin: 0, optimalMax: 0.1),
    silica: WaterParameter(name: 'Silica', value: avg((d) => d.roData!.silica.value), unit: 'ppm', optimalMin: 0, optimalMax: 150),
    roConductivity: WaterParameter(name: 'RO Conductivity', value: avg((d) => d.roData!.roConductivity.value), unit: 'µS/cm', optimalMin: 0, optimalMax: 50),
    timestamp: DateTime.now(),
  );
}

/// Average RO assessment scores
ROProtectionAssessment? _averageRoAssessment(List<DailyCalculation> days) {
  final daysWithRo = days.where((d) => d.roAssessment != null).toList();
  if (daysWithRo.isEmpty) return null;
  
  double avgOxidation = daysWithRo.map((d) => d.roAssessment!.oxidationRiskScore).reduce((a, b) => a + b) / daysWithRo.length;
  double avgSilica = daysWithRo.map((d) => d.roAssessment!.silicaScalingRiskScore).reduce((a, b) => a + b) / daysWithRo.length;
  double avgMembrane = daysWithRo.map((d) => d.roAssessment!.membraneLifeIndicator).reduce((a, b) => a + b) / daysWithRo.length;
  int validatedCount = daysWithRo.where((d) => d.roAssessment!.multiBarrierValidated).length;
  
  return ROProtectionAssessment(
    oxidationRiskScore: avgOxidation,
    silicaScalingRiskScore: avgSilica,
    multiBarrierValidated: validatedCount > daysWithRo.length / 2,
    membraneLifeIndicator: avgMembrane,
  );
}

/// Stores calculated values for a single day
class DailyCalculation {
  final DateTime date;
  final CoolingTowerData ctData;
  final ROData? roData;
  final CalculatedIndices indices;
  final RiskAssessment risk;
  final ROProtectionAssessment? roAssessment;
  final SystemHealth health;
  
  const DailyCalculation({
    required this.date,
    required this.ctData,
    this.roData,
    required this.indices,
    required this.risk,
    this.roAssessment,
    required this.health,
  });
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
  final List<DailyCalculation> dailyCalculations;
  
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
    required this.dailyCalculations,
  });
}

/// Simple date range holder
class DateRange {
  final DateTime start;
  final DateTime end;
  
  const DateRange(this.start, this.end);
  
  int get dayCount => end.difference(start).inDays + 1;
}
