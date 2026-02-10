import 'chemistry_models.dart';
import 'assessment_models.dart';

/// Represents a single water chemistry measurement at a specific point in time
class WaterMeasurement {
  final String id;
  final String factoryId;
  final DateTime measurementDate; // Actual measurement date from Excel
  
  // Raw data
  final CoolingTowerData ctData;
  final ROData? roData;
  
  // Pre-calculated (for display efficiency)
  final CalculatedIndices indices;
  final RiskAssessment risk;
  
  // Metadata
  final String sourceFileId;
  final String sourceFileName;
  final DateTime uploadedAt;

  const WaterMeasurement({
    required this.id,
    required this.factoryId,
    required this.measurementDate,
    required this.ctData,
    this.roData,
    required this.indices,
    required this.risk,
    required this.sourceFileId,
    required this.sourceFileName,
    required this.uploadedAt,
  });

  /// Create from database JSON
  factory WaterMeasurement.fromMap(Map<String, dynamic> map) {
    // Parse CT data
    final ctData = CoolingTowerData(
      ph: WaterParameter(name: 'pH', value: map['ph'] ?? 0.0, unit: 'pH'),
      alkalinity: WaterParameter(name: 'Total Alkalinity', value: map['alkalinity'] ?? 0.0, unit: 'ppm'),
      conductivity: WaterParameter(name: 'Conductivity', value: map['conductivity'] ?? 0.0, unit: 'µS/cm'),
      totalHardness: WaterParameter(name: 'Total Hardness', value: map['total_hardness'] ?? 0.0, unit: 'ppm'),
      chloride: WaterParameter(name: 'Chloride', value: map['chloride'] ?? 0.0, unit: 'ppm'),
      zinc: WaterParameter(name: 'Zinc', value: map['zinc'] ?? 0.0, unit: 'ppm'),
      iron: WaterParameter(name: 'Iron', value: map['iron'] ?? 0.0, unit: 'ppm'),
      phosphates: WaterParameter(name: 'Phosphates', value: map['phosphates'] ?? 0.0, unit: 'ppm'),
      timestamp: DateTime.parse(map['measurement_date']),
    );

    // Parse RO data if exists
    ROData? roData;
    if (map['ro_free_chlorine'] != null) {
      roData = ROData(
        freeChlorine: WaterParameter(name: 'Free Chlorine', value: map['ro_free_chlorine'], unit: 'ppm'),
        silica: WaterParameter(name: 'Silica', value: map['ro_silica'] ?? 0.0, unit: 'ppm'),
        roConductivity: WaterParameter(name: 'RO Conductivity', value: map['ro_conductivity'] ?? 0.0, unit: 'µS/cm'),
        timestamp: DateTime.parse(map['measurement_date']),
      );
    }

    final indices = CalculatedIndices(
      lsi: map['lsi'] ?? 0.0,
      rsi: map['rsi'] ?? 0.0,
      psi: map['psi'] ?? 0.0,
      larsonSkold: map['larson_skold'] ?? 0.0,
      coc: map['coc'] ?? 1.0,
      tdsEstimation: map['tds_estimation'] ?? 0.0,
      stiffDavis: map['stiff_davis'] ?? 0.0,
      adjustedPsi: map['adjusted_psi'] ?? 0.0,
      chlorideSulfateRatio: map['chloride_sulfate_ratio'] ?? 0.0,
      sulfateEstimated: map['sulfate_estimated'] ?? true, // Default to true for legacy data
      usedTemperature: map['used_temperature'] ?? 35.0, // Default to 35.0 for legacy data
      timestamp: DateTime.parse(map['measurement_date']),
    );

    // Parse risk
    final risk = RiskAssessment(
      scalingScore: map['risk_scaling'] ?? 0.0,
      corrosionScore: map['risk_corrosion'] ?? 0.0,
      foulingScore: map['risk_fouling'] ?? 0.0,
      scalingRisk: _getRiskLevel(map['risk_scaling'] ?? 0.0),
      corrosionRisk: _getRiskLevel(map['risk_corrosion'] ?? 0.0),
      foulingRisk: _getRiskLevel(map['risk_fouling'] ?? 0.0),
      timestamp: DateTime.parse(map['measurement_date']),
    );

    return WaterMeasurement(
      id: map['id'],
      factoryId: map['factory_id'],
      measurementDate: DateTime.parse(map['measurement_date']),
      ctData: ctData,
      roData: roData,
      indices: indices,
      risk: risk,
      sourceFileId: map['source_file_id'],
      sourceFileName: map['source_file_name'] ?? '',
      uploadedAt: DateTime.parse(map['uploaded_at']),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'factory_id': factoryId,
      'measurement_date': measurementDate.toIso8601String().split('T')[0], // Date only
      'ph': ctData.ph.value,
      'alkalinity': ctData.alkalinity.value,
      'conductivity': ctData.conductivity.value,
      'total_hardness': ctData.totalHardness.value,
      'chloride': ctData.chloride.value,
      'zinc': ctData.zinc.value,
      'iron': ctData.iron.value,
      'phosphates': ctData.phosphates.value,
      'ro_free_chlorine': roData?.freeChlorine.value,
      'ro_silica': roData?.silica.value,
      'ro_conductivity': roData?.roConductivity.value,
      'lsi': indices.lsi,
      'rsi': indices.rsi,
      'psi': indices.psi,
      'risk_scaling': risk.scalingScore,
      'risk_corrosion': risk.corrosionScore,
      'risk_fouling': risk.foulingScore,
      'source_file_id': sourceFileId,
      'source_file_name': sourceFileName,
    };
  }

  static RiskLevel _getRiskLevel(double score) {
    if (score >= 70) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 30) return RiskLevel.medium;
    return RiskLevel.low;
  }
}

/// Time period selection for analytics
enum TimePeriod { day, week, month, year, custom }

class TimePeriodSelection {
  final TimePeriod period;
  final DateTime startDate;
  final DateTime endDate;

  const TimePeriodSelection({
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  /// Last 24 hours
  factory TimePeriodSelection.lastDay() {
    final now = DateTime.now();
    return TimePeriodSelection(
      period: TimePeriod.day,
      startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// Last 7 days
  factory TimePeriodSelection.lastWeek() {
    final now = DateTime.now();
    return TimePeriodSelection(
      period: TimePeriod.week,
      startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// Last 30 days
  factory TimePeriodSelection.lastMonth() {
    final now = DateTime.now();
    return TimePeriodSelection(
      period: TimePeriod.month,
      startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// Last 365 days
  factory TimePeriodSelection.lastYear() {
    final now = DateTime.now();
    return TimePeriodSelection(
      period: TimePeriod.year,
      startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 365)),
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// Custom date range
  factory TimePeriodSelection.custom(DateTime start, DateTime end) {
    return TimePeriodSelection(
      period: TimePeriod.custom,
      startDate: start,
      endDate: end,
    );
  }

  int get daysInPeriod => endDate.difference(startDate).inDays;

  String get displayName {
    switch (period) {
      case TimePeriod.day:
        return 'Last Day';
      case TimePeriod.week:
        return 'Last Week';
      case TimePeriod.month:
        return 'Last Month';
      case TimePeriod.year:
        return 'Last Year';
      case TimePeriod.custom:
        return 'Custom Range';
    }
  }
}

/// Result of aggregating measurements over a time period
class AggregatedAnalytics {
  final TimePeriodSelection period;
  final int measurementCount;
  
  // Aggregated data (averaged parameters)
  final CoolingTowerData aggregatedData;
  final ROData? aggregatedRoData;
  
  // Recalculated from aggregated data
  final CalculatedIndices indices;
  final RiskAssessment risk;
  final SystemHealth health;
  
  // Trends
  final TrendData trends;

  const AggregatedAnalytics({
    required this.period,
    required this.measurementCount,
    required this.aggregatedData,
    this.aggregatedRoData,
    required this.indices,
    required this.risk,
    required this.health,
    required this.trends,
  });
}

/// Trend statistics for a parameter
class ParameterTrend {
  final double min;
  final double max;
  final double average;
  final double? standardDeviation;
  final TrendDirection direction; // upward, downward, stable

  const ParameterTrend({
    required this.min,
    required this.max,
    required this.average,
    this.standardDeviation,
    required this.direction,
  });

  double get range => max - min;
  double get variability => standardDeviation ?? 0.0;
}

enum TrendDirection { upward, downward, stable }

class TrendData {
  final ParameterTrend ph;
  final ParameterTrend alkalinity;
  final ParameterTrend conductivity;
  final ParameterTrend hardness;

  const TrendData({
    required this.ph,
    required this.alkalinity,
    required this.conductivity,
    required this.hardness,
  });
}
