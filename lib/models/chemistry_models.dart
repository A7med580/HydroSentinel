enum DataQuality {
  good,
  warning,
  suspect,
  invalid,
}

class WaterParameter {
  final String name;
  final double value;
  final String unit;
  final double? optimalMin;
  final double? optimalMax;
  final double? criticalThreshold;
  final DataQuality quality;

  WaterParameter({
    required this.name,
    required this.value,
    required this.unit,
    this.optimalMin,
    this.optimalMax,
    this.criticalThreshold,
    this.quality = DataQuality.good,
  });

  bool get isOptimal =>
      (optimalMin == null || value >= optimalMin!) &&
      (optimalMax == null || value <= optimalMax!);

  bool get isCritical =>
      criticalThreshold != null && value >= criticalThreshold!;
}

class CoolingTowerData {
  final WaterParameter ph;
  final WaterParameter alkalinity;
  final WaterParameter conductivity;
  final WaterParameter totalHardness;
  final WaterParameter chloride;
  final WaterParameter zinc;
  final WaterParameter iron;
  final WaterParameter phosphates;
  final WaterParameter? temperature; // Optional: parsed from Excel or null (engine defaults to 35°C for CT)
  final WaterParameter? sulfate;     // Optional: if measured, used for Larson-Skold; if null, estimated from chloride
  final DateTime timestamp;

  CoolingTowerData({
    required this.ph,
    required this.alkalinity,
    required this.conductivity,
    required this.totalHardness,
    required this.chloride,
    required this.zinc,
    required this.iron,
    required this.phosphates,
    this.temperature,
    this.sulfate,
    required this.timestamp,
  });
}

class ROData {
  final WaterParameter freeChlorine;
  final WaterParameter silica;
  final WaterParameter roConductivity;
  final DateTime timestamp;

  ROData({
    required this.freeChlorine,
    required this.silica,
    required this.roConductivity,
    required this.timestamp,
  });
}
