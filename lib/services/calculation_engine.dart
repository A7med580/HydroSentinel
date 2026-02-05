import 'dart:math';
import '../models/chemistry_models.dart';
import '../models/assessment_models.dart';

class CalculationEngine {
  // Layer 1: Raw Chemistry Validation
  static DataQuality validateParameter(double value, double? min, double? max, {List<double>? history}) {
    if (min != null && max != null) {
      if (value < min * 0.5 || value > max * 1.5) {
        return DataQuality.invalid;
      }
      if (value < min || value > max) {
        return DataQuality.warning;
      }
    }

    if (history != null && history.isNotEmpty) {
      double mean = history.reduce((a, b) => a + b) / history.length;
      double variance = history.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / history.length;
      double stdDev = sqrt(variance);
      
      if (stdDev > 0 && (value - mean).abs() > 3 * stdDev) {
        return DataQuality.suspect;
      }
    }

    return DataQuality.good;
  }

  // Layer 2: Advanced Indices Calculation
  static CalculatedIndices calculateIndices(CoolingTowerData data) {
    double temp = 25.0; 
    double ph = data.ph.value;
    double alk = data.alkalinity.value;
    double hard = data.totalHardness.value;
    double cond = data.conductivity.value;
    double cl = data.chloride.value;

    double tds = cond * 0.67;
    double A = (log10(tds) - 1) / 10;
    double B = -13.12 * log10(temp + 273.15) + 34.55;
    double C = log10(hard) - 0.4;
    double D = log10(alk);
    double phs = (9.3 + A + B) - (C + D);
    double lsi = ph - phs;

    double rsi = 2 * phs - ph;

    double phEquil = 1.465 * log10(alk) + 4.54;
    double psi = 2 * phs - phEquil;

    double stiffDavis = lsi; 

    double sulfate = cl * 0.5; 
    double larsonSkold = (cl + sulfate) / alk;

    double coc = cond / 200.0;

    double adjustedPsi = psi * 1.05;

    double tdsEstimation = tds;

    double chlorideSulfateRatio = cl / (sulfate > 0 ? sulfate : 1.0);

    return CalculatedIndices(
      lsi: lsi,
      rsi: rsi,
      psi: psi,
      stiffDavis: stiffDavis,
      larsonSkold: larsonSkold,
      coc: coc,
      adjustedPsi: adjustedPsi,
      tdsEstimation: tdsEstimation,
      chlorideSulfateRatio: chlorideSulfateRatio,
    );
  }

  // Layer 3 — Multi-Factor Risk Assessment
  static RiskAssessment assessRisk(CalculatedIndices indices, CoolingTowerData data) {
    double scalingScore = 0;
    if (indices.lsi > 0) {
      scalingScore += indices.lsi * 20;
    }
    if (indices.psi < 6) {
      scalingScore += (6 - indices.psi) * 15;
    }
    scalingScore = scalingScore.clamp(0, 100);

    double corrosionScore = 0;
    if (indices.larsonSkold > 1.2) {
      corrosionScore += (indices.larsonSkold - 1.2) * 25;
    }
    if (data.chloride.value > 250) {
      corrosionScore += (data.chloride.value - 250) / 10;
    }
    corrosionScore = corrosionScore.clamp(0, 100);

    double foulingScore = 0;
    if (data.iron.value > 0.5) {
      foulingScore += (data.iron.value - 0.5) * 40;
    }
    if (data.phosphates.value > 10) {
      foulingScore += (data.phosphates.value - 10) * 5;
    }
    foulingScore = foulingScore.clamp(0, 100);

    return RiskAssessment(
      scalingScore: scalingScore,
      corrosionScore: corrosionScore,
      foulingScore: foulingScore,
      scalingRisk: _getRiskLevel(scalingScore),
      corrosionRisk: _getRiskLevel(corrosionScore),
      foulingRisk: _getRiskLevel(foulingScore),
    );
  }

  // Layer 4 — RO Protection Assessment
  static ROProtectionAssessment assessRO(ROData data) {
    double oxidationRisk = (data.freeChlorine.value > 0.1) ? (data.freeChlorine.value * 500).clamp(0, 100) : 0;
    
    double silicaRisk = (data.silica.value > 150) ? (data.silica.value - 150) * 2 : 5;
    silicaRisk = silicaRisk.clamp(0, 100);

    bool multiBarrier = data.freeChlorine.value < 0.1 && data.roConductivity.value < 50;
    
    double membraneLife = 100 - (oxidationRisk * 0.6 + silicaRisk * 0.4);

    return ROProtectionAssessment(
      oxidationRiskScore: oxidationRisk,
      silicaScalingRiskScore: silicaRisk,
      multiBarrierValidated: multiBarrier,
      membraneLifeIndicator: membraneLife.clamp(0, 100),
    );
  }

  // Layer 5 — Health Scoring System
  static SystemHealth calculateHealth(RiskAssessment risk, ROProtectionAssessment? roRisk) {
    double averageRisk = (risk.scalingScore + risk.corrosionScore + risk.foulingScore) / 3;
    double score = 100 - averageRisk;
    
    if (roRisk != null) {
      score = (score + roRisk.membraneLifeIndicator) / 2;
    }

    String status;
    List<String> issues = [];

    if (score > 85) {
      status = "Excellent";
    } else if (score > 70) {
      status = "Good";
    } else if (score > 50) {
      status = "Fair";
    } else if (score > 30) {
      status = "Poor";
    } else {
      status = "Critical";
    }

    if (risk.scalingScore > 50) {
      issues.add("High Scaling Potential");
    }
    if (risk.corrosionScore > 50) {
      issues.add("Active Corrosion Risk");
    }
    if (risk.foulingScore > 50) {
      issues.add("Suspended Solids / Fouling");
    }
    if (roRisk != null && roRisk.oxidationRiskScore > 20) {
      issues.add("Membrane Oxidation Warning");
    }

    return SystemHealth(
      overallScore: score.clamp(0, 100),
      status: status,
      keyIssues: issues,
    );
  }

  // Layer 6 — Actionable Recommendations
  static List<Recommendation> generateRecommendations(RiskAssessment risk, SystemHealth health, ROData? roData) {
    List<Recommendation> recs = [];

    if (risk.scalingRisk == RiskLevel.high || risk.scalingRisk == RiskLevel.critical) {
      recs.add(Recommendation(
        title: "Scale Inhibitor Adjustment",
        description: "Increase scale inhibitor dosage due to high scaling index.",
        priority: RecommendationPriority.critical,
        category: RecommendationCategory.chemicalDosing,
        actionSteps: ["Check dosing pump calibration", "Increase dosage by 15%", "Re-test LSI in 24h"],
      ));
    }

    if (risk.corrosionRisk == RiskLevel.high) {
      recs.add(Recommendation(
        title: "Corrosion Protection",
        description: "Elevated Larson-Skold ratio detected.",
        priority: RecommendationPriority.high,
        category: RecommendationCategory.chemicalDosing,
        actionSteps: ["Inspect coupon racks", "Review azole levels", "Monitor iron trends"],
      ));
    }

    if (roData != null && roData.freeChlorine.value > 0.1) {
      recs.add(Recommendation(
        title: "De-chlorination Failure",
        description: "Free chlorine detected upstream of RO membranes.",
        priority: RecommendationPriority.critical,
        category: RecommendationCategory.operationalAdjustments,
        actionSteps: ["Check SBS dosing system", "Inspect carbon filter breakthrough", "Immediate shutdown if chlorine > 0.5 ppm"],
      ));
    }

    return recs;
  }

  static RiskLevel _getRiskLevel(double score) {
    if (score < 20) {
      return RiskLevel.low;
    }
    if (score < 50) {
      return RiskLevel.medium;
    }
    if (score < 80) {
      return RiskLevel.high;
    }
    return RiskLevel.critical;
  }

  static double log10(num x) => log(x) / ln10;
}
