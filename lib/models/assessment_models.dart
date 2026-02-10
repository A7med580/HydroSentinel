enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

class CalculatedIndices {
  final double lsi;
  final double rsi;
  final double psi;
  final double? stiffDavis;    // Null if TDS < 1000 (S&D designed for high-TDS brines)
  final double? larsonSkold;   // Null if sulfate not measured and safe mode is active
  final double coc;
  final double adjustedPsi;
  final double tdsEstimation;
  final double chlorideSulfateRatio;
  final double usedTemperature;   // Actual temperature used in calculation (for traceability)
  final bool sulfateEstimated;    // True if sulfate was estimated from chloride
  final DateTime timestamp;

  CalculatedIndices({
    required this.lsi,
    required this.rsi,
    required this.psi,
    this.stiffDavis,
    this.larsonSkold,
    required this.coc,
    required this.adjustedPsi,
    required this.tdsEstimation,
    required this.chlorideSulfateRatio,
    required this.usedTemperature,
    required this.sulfateEstimated,
    required this.timestamp,
  });
}

class RiskAssessment {
  final double scalingScore;
  final double corrosionScore;
  final double foulingScore;
  final RiskLevel scalingRisk;
  final RiskLevel corrosionRisk;
  final RiskLevel foulingRisk;
  final DateTime timestamp;

  RiskAssessment({
    required this.scalingScore,
    required this.corrosionScore,
    required this.foulingScore,
    required this.scalingRisk,
    required this.corrosionRisk,
    required this.foulingRisk,
    required this.timestamp,
  });
}

class ROProtectionAssessment {
  final double oxidationRiskScore;
  final double silicaScalingRiskScore;
  final bool multiBarrierValidated;
  final double membraneLifeIndicator; // 0-100

  ROProtectionAssessment({
    required this.oxidationRiskScore,
    required this.silicaScalingRiskScore,
    required this.multiBarrierValidated,
    required this.membraneLifeIndicator,
  });
}

class SystemHealth {
  final double overallScore;
  final String status; // Excellent, Good, Fair, Poor, Critical
  final List<String> keyIssues;

  SystemHealth({
    required this.overallScore,
    required this.status,
    required this.keyIssues,
  });
}

enum RecommendationPriority {
  critical,
  high,
  medium,
  low,
}

enum RecommendationCategory {
  chemicalDosing,
  operationalAdjustments,
  equipmentMaintenance,
  systemUpgrades,
}

class Recommendation {
  final String title;
  final String description;
  final RecommendationPriority priority;
  final RecommendationCategory category;
  final List<String> actionSteps;

  Recommendation({
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.actionSteps,
  });
}
