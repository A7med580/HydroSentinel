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
      timestamp: data.timestamp,
    );
  }

  // Layer 3 — Multi-Factor Risk Assessment (Acqua Guard Spec)
  static RiskAssessment assessRisk(CalculatedIndices indices, CoolingTowerData data) {
    // A. Scaling Risk (0-100)
    // 1. Hardness (40%) - Target 20-40, Critical > 200
    // 2. Alkalinity (30%) - Target 100-200, Critical > 400
    // 3. pH (20%) - Target 7.0-8.5
    // 4. LSI (10%) - Target -0.5 to +0.5
    double scalingScore = 0;
    scalingScore += _calcScore(data.totalHardness.value, 20, 40, weight: 40, criticalMax: 200);
    scalingScore += _calcScore(data.alkalinity.value, 100, 200, weight: 30, criticalMax: 400);
    scalingScore += _calcScore(data.ph.value, 7.0, 8.5, weight: 20, criticalMin: 6.5, criticalMax: 9.0);
    // LSI > 0.5 is scaling risk
    if (indices.lsi > 0.5) scalingScore += ((indices.lsi - 0.5) * 10).clamp(0, 10); // Simple linear up to max weight

    // B. Corrosion Risk (0-100)
    // 1. Zinc (30%) - Target 1.5-2.5, Critical < 0.5
    // 2. Chloride (25%) - Target < 100, Critical > 500
    // 3. pH (20%) - Low pH is corrosive
    // 4. RSI (15%) - RSI > 7.5 is corrosive
    // 5. Larson-Skold (10%) - > 1.2 is high risk
    double corrosionScore = 0;
    corrosionScore += _calcScore(data.zinc.value, 1.5, 2.5, weight: 30, criticalMin: 0.5, invert: true); // Low zinc = Bad
    corrosionScore += (data.chloride.value > 100) ? ((data.chloride.value - 100) / 400 * 25).clamp(0, 25) : 0;
    corrosionScore += (data.ph.value < 7.0) ? ((7.0 - data.ph.value) * 20).clamp(0, 20) : 0;
    corrosionScore += (indices.rsi > 7.5) ? ((indices.rsi - 7.5) * 15).clamp(0, 15) : 0;
    corrosionScore += (indices.larsonSkold > 1.2) ? ((indices.larsonSkold - 1.2) * 10).clamp(0, 10) : 0;

    // C. Fouling Risk (0-100)
    // 1. Iron (40%) - Target < 0.3, Critical > 2.0
    // 2. Phosphates (30%) - Target 12-18, Critical > 30 (PO4 ppt risk) or < 5 (no inhibition)
    // 3. Conductivity (20%) - Target < 2000, Critical > 5000
    // 4. Silica (10%) - Not in CT input yet, assume minimal risk
    double foulingScore = 0;
    foulingScore += (data.iron.value > 0.3) ? ((data.iron.value - 0.3) / 1.7 * 40).clamp(0, 40) : 0;
    
    // Phosphate risk: either too high (scaling/fouling) or too low (fouling/scaling indirect). 
    // PDF says "Phosphate Balance (30%)". Let's penalize deviation from 12-18.
    foulingScore += _calcScore(data.phosphates.value, 12, 18, weight: 30, criticalMax: 30, criticalMin: 5);
    
    foulingScore += (data.conductivity.value > 2000) ? ((data.conductivity.value - 2000) / 3000 * 20).clamp(0, 20) : 0;
    // Silica placeholder (10%)
    foulingScore += 0; 

    return RiskAssessment(
      scalingScore: scalingScore.clamp(0, 100),
      corrosionScore: corrosionScore.clamp(0, 100),
      foulingScore: foulingScore.clamp(0, 100),
      scalingRisk: _getRiskLevel(scalingScore),
      corrosionRisk: _getRiskLevel(corrosionScore),
      foulingRisk: _getRiskLevel(foulingScore),
      timestamp: data.timestamp,
    );
  }

  // Helper calculation for weighted deviation
  static double _calcScore(double val, double optMin, double optMax, {
    required double weight, 
    double? criticalMin, 
    double? criticalMax,
    bool invert = false, // If true, finding value being LOW is the risk (e.g. Zinc)
  }) {
    if (val >= optMin && val <= optMax) return 0; // In optimal range = 0 risk
    
    double riskRatio = 0;
    
    if (val < optMin) {
        // Just deviation, or checking against critical low?
        if (invert) {
           // For Zinc: < 1.0 is bad. 1.5 is good.
           // risk increases as we go from optMin down to criticalMin (or 0)
           double limit = criticalMin ?? 0;
           double range = optMin - limit;
           if (range == 0) return weight;
           riskRatio = (optMin - val) / range;
        } else {
           // For simple parameters, deviation below might just be 0 risk if we only care about HIGH (like Hardness) 
           // BUT PDF says "Hardness Contribution". Low hardness could be Corrosion risk, not Scaling.
           // Scaling Risk for Hardness: Only High Hardness matters? 
           // "Too High (> 50): Calcium carbonate scaling". 
           // So for Scaling Risk, Low Hardness is 0 risk.
           return 0; 
        }
    } else if (val > optMax) {
        if (invert) return 0; // High value is fine (unless specified otherwise)
        
        // High Value Risk (e.g. Hardness > 40)
        double limit = criticalMax ?? (optMax * 2);
        double range = limit - optMax;
        if (range == 0) return weight;
        riskRatio = (val - optMax) / range;
    }
    
    return (riskRatio * weight).clamp(0, weight);
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
    // 1. Water Chemistry Health (35%)
    // Simplified: 100 - Avg(Risk Scores) roughly maps to chemistry deviation
    // Better: We should pass in the raw data to calculate this properly, but deriving from Risk is acceptable proxy
    double riskAvg = (risk.scalingScore + risk.corrosionScore + risk.foulingScore) / 3;
    double chemistryScore = (100 - riskAvg).clamp(0, 100);
    
    // 2. Risk Profile Health (35%)
    // "Inverse of combined risk scores"
    double maxRisk = risk.scalingScore;
    if (risk.corrosionScore > maxRisk) maxRisk = risk.corrosionScore;
    if (risk.foulingScore > maxRisk) maxRisk = risk.foulingScore;
    
    double riskProfileScore = (100 - maxRisk).clamp(0, 100);
    
    // 3. Treatment Effectiveness (20%) - & 4. Stability (10%)
    // Placeholder: Assume 80% effectiveness if risks are low, 40% if high
    double treatmentScore = (riskAvg < 20) ? 90 : (100 - riskAvg * 1.5).clamp(0, 100);
    double stabilityScore = 80; // Placeholder until we have history
    
    double overallScore = (chemistryScore * 0.35) + 
                          (riskProfileScore * 0.35) + 
                          (treatmentScore * 0.20) + 
                          (stabilityScore * 0.10);
                          
    if (roRisk != null) {
       // Blend RO health if available (50/50 split with CT)
       double roHealth = roRisk.membraneLifeIndicator;
       overallScore = (overallScore + roHealth) / 2;
    }

    String status;
    List<String> issues = [];

    if (overallScore > 85) {
      status = "Excellent";
    } else if (overallScore > 70) {
      status = "Good";
    } else if (overallScore > 50) {
      status = "Fair";
    } else if (overallScore > 30) {
      status = "Poor";
    } else {
      status = "Critical";
    }

    if (risk.scalingScore > 40) issues.add("Scaling Risk");
    if (risk.corrosionScore > 40) issues.add("Corrosion Risk");
    if (risk.foulingScore > 40) issues.add("Fouling/Deposition");
    if (roRisk != null && roRisk.oxidationRiskScore > 20) issues.add("RO Membrane Oxidation");

    return SystemHealth(
      overallScore: overallScore.clamp(0, 100),
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
