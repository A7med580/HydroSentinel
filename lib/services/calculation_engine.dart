import 'dart:math';
import '../models/chemistry_models.dart';
import '../models/assessment_models.dart';

/// HydroSentinel Calculation Engine — Production v1.0
/// 
/// Implements industrial water chemistry index calculations per published references:
/// - LSI: Langelier, W.F. (1936). "The Analytical Control of Anti-Corrosion Water Treatment"
/// - RSI: Ryznar, J.W. (1944). "A New Index for Determining Amount of Calcium Carbonate Scale"
/// - PSI: Puckorius, P.R. & Brooke, J.M. (1991). "A New Practical Index for Calcium Carbonate Scale"
/// - Stiff-Davis: Stiff, H.A. & Davis, L.E. (1952). "A Method for Predicting the Tendency of Oil Field Waters to Deposit Calcium Carbonate"
/// - Larson-Skold: Larson, T.E. & Skold, R.V. (1958). "Laboratory Studies Relating Mineral Quality of Water to Corrosion of Steel and Cast Iron"
class CalculationEngine {

  // ──────────────────────────────────────────────────────────
  // Task 1.7: Parameter Bounds Validation
  // ──────────────────────────────────────────────────────────
  
  /// Returns null if value is valid; returns error message if out of bounds.
  static String? validateParameterBounds(String name, double value) {
    switch (name.toLowerCase()) {
      case 'ph':
        if (value < 0 || value > 14) return 'pH=$value out of range [0-14]';
        break;
      case 'alkalinity':
      case 'alk':
        if (value < 0 || value > 1000) return 'Alkalinity=$value out of range [0-1000]';
        break;
      case 'hardness':
      case 'hard':
        if (value < 0 || value > 2000) return 'Hardness=$value out of range [0-2000]';
        break;
      case 'conductivity':
      case 'cond':
        if (value < 0 || value > 10000) return 'Conductivity=$value out of range [0-10000]';
        break;
      case 'chloride':
      case 'cl':
        if (value < 0 || value > 5000) return 'Chloride=$value out of range [0-5000]';
        break;
      case 'temperature':
      case 'temp':
        if (value < 5 || value > 60) return 'Temperature=$value out of range [5-60]';
        break;
      case 'zinc':
      case 'zn':
        if (value < 0 || value > 50) return 'Zinc=$value out of range [0-50]';
        break;
      case 'iron':
      case 'fe':
        if (value < 0 || value > 100) return 'Iron=$value out of range [0-100]';
        break;
      case 'phosphate':
      case 'po4':
        if (value < 0 || value > 200) return 'Phosphate=$value out of range [0-200]';
        break;
      case 'sulfate':
      case 'so4':
        if (value < 0 || value > 5000) return 'Sulfate=$value out of range [0-5000]';
        break;
      default:
        if (value < 0) return '$name=$value is negative';
    }
    return null;
  }

  /// Validates all parameters in CoolingTowerData. Returns list of error messages (empty if all valid).
  static List<String> validateAllParameters(CoolingTowerData data) {
    final errors = <String>[];
    void check(String name, double value) {
      final err = validateParameterBounds(name, value);
      if (err != null) errors.add(err);
    }
    check('ph', data.ph.value);
    check('alkalinity', data.alkalinity.value);
    check('hardness', data.totalHardness.value);
    check('conductivity', data.conductivity.value);
    check('chloride', data.chloride.value);
    check('zinc', data.zinc.value);
    check('iron', data.iron.value);
    check('phosphate', data.phosphates.value);
    if (data.temperature != null) check('temperature', data.temperature!.value);
    if (data.sulfate != null) check('sulfate', data.sulfate!.value);
    return errors;
  }

  // ──────────────────────────────────────────────────────────
  // Layer 1: Raw Chemistry Validation
  // ──────────────────────────────────────────────────────────

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

  // ──────────────────────────────────────────────────────────
  // Layer 2: Advanced Indices Calculation
  // Fixed: Task 1.1 (temperature), 1.2 (Stiff-Davis), 1.3 (sulfate), 1.6 (PSI NaN guard)
  // ──────────────────────────────────────────────────────────

  static CalculatedIndices calculateIndices(CoolingTowerData data) {
    // Task 1.1: Use actual temperature if available, default 35°C for cooling towers
    // Ref: Cooling towers typically operate at 30-50°C; 35°C is industry standard default
    double temp = data.temperature?.value ?? 35.0;
    
    double ph = data.ph.value;
    double alk = data.alkalinity.value;
    double hard = data.totalHardness.value;
    double cond = data.conductivity.value;
    double cl = data.chloride.value;

    // Guards against log10(0) — Task 1.6 (PSI NaN guard also applied here)
    double safeAlk = max(alk, 0.1);
    double safeHard = max(hard, 0.1);
    double safeCond = max(cond, 0.1);

    // ── LSI (Langelier Saturation Index) ──
    // Ref: Langelier (1936) — standard aqueous carbonate equilibrium
    double tds = safeCond * 0.67;
    double A = (log10(tds) - 1) / 10;
    double B = -13.12 * log10(temp + 273.15) + 34.55;
    double C = log10(safeHard) - 0.4;
    double D = log10(safeAlk);
    double phs = (9.3 + A + B) - (C + D);
    double lsi = ph - phs;

    // ── RSI (Ryznar Stability Index) ──
    // Ref: Ryznar (1944)
    double rsi = 2 * phs - ph;

    // ── PSI (Puckorius Scaling Index) ──
    // Task 1.6: Use guarded safeAlk to prevent NaN
    // Ref: Puckorius & Brooke (1991)
    double phEquil = 1.465 * log10(safeAlk) + 4.54;
    double psi = 2 * phs - phEquil;

    // ── Stiff-Davis Saturation Index ──
    // Task 1.2: Proper implementation with ionic strength correction
    // Ref: Stiff & Davis (1952) — designed for high-TDS produced waters (>1000 mg/L)
    // Returns null if TDS < 1000 (index not applicable for low-TDS systems)
    double? stiffDavis;
    if (tds >= 1000) {
      // Ionic strength approximation: I ≈ 2.5 × 10⁻⁵ × TDS
      double ionicStrength = 2.5e-5 * tds;
      // Activity coefficient correction using Davies equation approximation
      // -log(γ) ≈ 0.509 × (√I / (1 + √I) - 0.3 × I)
      double sqrtI = sqrt(ionicStrength);
      double logGamma = 0.509 * (sqrtI / (1 + sqrtI) - 0.3 * ionicStrength);
      // Corrected pHs for high-TDS: adjust for activity coefficients of Ca²⁺ and CO₃²⁻
      // Each divalent ion contributes 4× logGamma correction
      double phs_SD = phs - 4 * logGamma;
      stiffDavis = ph - phs_SD;
    }

    // ── Larson-Skold Index ──
    // Task 1.3: Use actual sulfate if measured, else estimate from chloride
    // Ref: Larson & Skold (1958) — (Cl⁻ + SO₄²⁻) / alkalinity in meq/L
    bool sulfateEstimated;
    double sulfate;
    if (data.sulfate != null && data.sulfate!.value > 0) {
      sulfate = data.sulfate!.value;
      sulfateEstimated = false;
    } else {
      // Estimation: sulfate ≈ chloride × 0.5 (common industrial approximation)
      sulfate = cl * 0.5;
      sulfateEstimated = true;
    }
    // Convert to meq/L: Cl⁻ (MW=35.45, charge=1), SO₄²⁻ (MW=96.06, charge=2)
    double clMeq = cl / 35.45;
    double so4Meq = sulfate / (96.06 / 2); // divide by equivalent weight = 48.03
    double alkMeq = safeAlk / 50.0; // CaCO₃ equivalent weight = 50
    double? larsonSkold = (alkMeq > 0) ? (clMeq + so4Meq) / alkMeq : null;

    // ── Cycles of Concentration ──
    // Ref: CoC = circulating water conductivity / makeup water conductivity
    // Using 200 µS/cm as assumed makeup water conductivity (standard municipal supply)
    double coc = safeCond / 200.0;

    double adjustedPsi = psi * 1.05;
    double tdsEstimation = tds;
    double chlorideSulfateRatio = (sulfate > 0) ? cl / sulfate : 0.0;

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
      usedTemperature: temp,
      sulfateEstimated: sulfateEstimated,
      timestamp: data.timestamp,
    );
  }

  // ──────────────────────────────────────────────────────────
  // Layer 3: Multi-Factor Risk Assessment
  // Fixed: Task 1.3 (nullable Larson-Skold), Task 1.4 (silica fouling)
  // ──────────────────────────────────────────────────────────

  static RiskAssessment assessRisk(CalculatedIndices indices, CoolingTowerData data, {ROData? roData}) {
    // ── A. Scaling Risk (0-100) ──
    // Hardness 40%, Alkalinity 30%, pH 20%, LSI 10%
    double scalingScore = 0;
    scalingScore += _calcScore(data.totalHardness.value, 20, 40, weight: 40, criticalMax: 200);
    scalingScore += _calcScore(data.alkalinity.value, 100, 200, weight: 30, criticalMax: 400);
    scalingScore += _calcScore(data.ph.value, 7.0, 8.5, weight: 20, criticalMin: 6.5, criticalMax: 9.0);
    if (indices.lsi > 0.5) scalingScore += ((indices.lsi - 0.5) * 10).clamp(0, 10);

    // ── B. Corrosion Risk (0-100) ──
    // Task 1.3: Handle nullable Larson-Skold — redistribute 10% weight
    double corrosionScore = 0;
    if (indices.larsonSkold != null) {
      // Full weights: Zinc 30%, Chloride 25%, pH 20%, RSI 15%, Larson-Skold 10%
      corrosionScore += _calcScore(data.zinc.value, 1.5, 2.5, weight: 30, criticalMin: 0.5, invert: true);
      corrosionScore += (data.chloride.value > 100) ? ((data.chloride.value - 100) / 400 * 25).clamp(0, 25) : 0;
      corrosionScore += (data.ph.value < 7.0) ? ((7.0 - data.ph.value) * 20).clamp(0, 20) : 0;
      corrosionScore += (indices.rsi > 7.5) ? ((indices.rsi - 7.5) * 15).clamp(0, 15) : 0;
      corrosionScore += (indices.larsonSkold! > 1.2) ? ((indices.larsonSkold! - 1.2) * 10).clamp(0, 10) : 0;
    } else {
      // Redistributed weights without Larson-Skold: Zinc 33%, Chloride 28%, pH 22%, RSI 17%
      corrosionScore += _calcScore(data.zinc.value, 1.5, 2.5, weight: 33, criticalMin: 0.5, invert: true);
      corrosionScore += (data.chloride.value > 100) ? ((data.chloride.value - 100) / 400 * 28).clamp(0, 28) : 0;
      corrosionScore += (data.ph.value < 7.0) ? ((7.0 - data.ph.value) * 22).clamp(0, 22) : 0;
      corrosionScore += (indices.rsi > 7.5) ? ((indices.rsi - 7.5) * 17).clamp(0, 17) : 0;
    }

    // ── C. Fouling Risk (0-100) ──
    // Task 1.4: Implement silica contribution from RO data
    double foulingScore = 0;
    bool hasSilica = roData != null && roData.silica.value > 0;
    
    if (hasSilica) {
      // Full weights: Iron 40%, Phosphates 30%, Conductivity 20%, Silica 10%
      foulingScore += (data.iron.value > 0.3) ? ((data.iron.value - 0.3) / 1.7 * 40).clamp(0, 40) : 0;
      foulingScore += _calcScore(data.phosphates.value, 12, 18, weight: 30, criticalMax: 30, criticalMin: 5);
      foulingScore += (data.conductivity.value > 2000) ? ((data.conductivity.value - 2000) / 3000 * 20).clamp(0, 20) : 0;
      // Silica: >150 ppm causes severe fouling. Ref: ASHRAE Handbook — HVAC Applications
      double silicaScore = (roData!.silica.value > 150) 
          ? ((roData.silica.value - 150) / 50).clamp(0.0, 100.0) 
          : 0;
      foulingScore += silicaScore * 0.10;
    } else {
      // Redistributed weights without silica: Iron 44%, Phosphates 33%, Conductivity 23%
      foulingScore += (data.iron.value > 0.3) ? ((data.iron.value - 0.3) / 1.7 * 44).clamp(0, 44) : 0;
      foulingScore += _calcScore(data.phosphates.value, 12, 18, weight: 33, criticalMax: 30, criticalMin: 5);
      foulingScore += (data.conductivity.value > 2000) ? ((data.conductivity.value - 2000) / 3000 * 23).clamp(0, 23) : 0;
    }

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
    bool invert = false,
  }) {
    if (val >= optMin && val <= optMax) return 0;
    
    double riskRatio = 0;
    
    if (val < optMin) {
        if (invert) {
           double limit = criticalMin ?? 0;
           double range = optMin - limit;
           if (range == 0) return weight;
           riskRatio = (optMin - val) / range;
        } else {
           return 0; 
        }
    } else if (val > optMax) {
        if (invert) return 0;
        
        double limit = criticalMax ?? (optMax * 2);
        double range = limit - optMax;
        if (range == 0) return weight;
        riskRatio = (val - optMax) / range;
    }
    
    return (riskRatio * weight).clamp(0, weight);
  }

  // ──────────────────────────────────────────────────────────
  // Layer 4: RO Protection Assessment
  // ──────────────────────────────────────────────────────────

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

  // ──────────────────────────────────────────────────────────
  // Layer 5: Health Scoring System
  // Fixed: Task 1.5 — Treatment score based on actual chemical levels,
  //        stability score calculated from time-series variance
  // ──────────────────────────────────────────────────────────

  static SystemHealth calculateHealth(
    RiskAssessment risk,
    ROProtectionAssessment? roRisk, {
    CoolingTowerData? ctData,
    ROData? roData,
    List<double>? historicalPh,
    List<double>? historicalConductivity,
  }) {
    // 1. Water Chemistry Health (35%)
    double riskAvg = (risk.scalingScore + risk.corrosionScore + risk.foulingScore) / 3;
    double chemistryScore = (100 - riskAvg).clamp(0, 100);
    
    // 2. Risk Profile Health (35%)
    double maxRisk = [risk.scalingScore, risk.corrosionScore, risk.foulingScore]
        .reduce((a, b) => a > b ? a : b);
    double riskProfileScore = (100 - maxRisk).clamp(0, 100);
    
    // 3. Treatment Effectiveness (Task 1.5 — based on actual chemical levels)
    double treatmentScore;
    if (ctData != null) {
      treatmentScore = 0;
      // Zinc in optimal range (1.5-2.5 ppm) → corrosion inhibitor effective
      if (ctData.zinc.value >= 1.5 && ctData.zinc.value <= 2.5) {
        treatmentScore += 40;
      } else if (ctData.zinc.value >= 1.0 && ctData.zinc.value <= 3.0) {
        treatmentScore += 20; // Partially effective
      }
      // Phosphate in optimal range (12-18 ppm) → scale inhibitor effective
      if (ctData.phosphates.value >= 12 && ctData.phosphates.value <= 18) {
        treatmentScore += 40;
      } else if (ctData.phosphates.value >= 8 && ctData.phosphates.value <= 25) {
        treatmentScore += 20; // Partially effective
      }
      // Free chlorine properly controlled (if RO data available)
      if (roData != null && roData.freeChlorine.value <= 0.1) {
        treatmentScore += 20; // Proper dechlorination
      } else if (roData == null) {
        treatmentScore += 10; // No RO data — assume partial credit
      }
    } else {
      // Fallback: derive from risk (legacy behavior when ctData not available)
      treatmentScore = (riskAvg < 20) ? 90 : (100 - riskAvg * 1.5).clamp(0, 100);
    }

    // 4. Stability Score (Task 1.5 — from time-series variance, or null for single point)
    double stabilityScore;
    double stabilityWeight = 0.10;
    double treatmentWeight = 0.20;
    
    if (historicalPh != null && historicalPh.length > 1 &&
        historicalConductivity != null && historicalConductivity.length > 1) {
      // Calculate coefficient of variation for pH and conductivity
      double phStdDev = _stdDev(historicalPh);
      double condStdDev = _stdDev(historicalConductivity);
      double condMean = historicalConductivity.reduce((a, b) => a + b) / historicalConductivity.length;
      
      // Normalize: pH std dev of 0.5 = poor stability, conductivity CV of 20% = poor
      double phPenalty = (phStdDev / 0.5 * 50).clamp(0, 50);
      double condPenalty = condMean > 0 ? (condStdDev / condMean * 250).clamp(0, 50) : 0;
      stabilityScore = (100 - phPenalty - condPenalty).clamp(0, 100);
    } else {
      // Single measurement: redistribute stability weight to other factors
      stabilityScore = 0;
      stabilityWeight = 0;
      treatmentWeight = 0.30; // Absorb stability's 10% into treatment's 20%
    }
                          
    double overallScore = (chemistryScore * 0.35) + 
                          (riskProfileScore * 0.35) + 
                          (treatmentScore * treatmentWeight) + 
                          (stabilityScore * stabilityWeight);
                          
    if (roRisk != null) {
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

  /// Standard deviation utility
  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  // ──────────────────────────────────────────────────────────
  // Layer 6: Actionable Recommendations with WHY explanations
  // ──────────────────────────────────────────────────────────

  static List<Recommendation> generateRecommendations(
    RiskAssessment risk, 
    SystemHealth health, 
    ROData? roData, {
    CoolingTowerData? ctData,
    CalculatedIndices? indices,
  }) {
    List<Recommendation> recs = [];

    // Alert 1: High Scaling Risk
    if (risk.scalingRisk == RiskLevel.high || risk.scalingRisk == RiskLevel.critical) {
      String detail = 'Scaling risk score: ${risk.scalingScore.toStringAsFixed(0)}%.';
      if (ctData != null) {
        detail += ' Hardness=${ctData.totalHardness.value} ppm (optimal: 20-40).';
        detail += ' Alkalinity=${ctData.alkalinity.value} ppm (optimal: 100-200).';
      }
      if (indices != null) {
        detail += ' LSI=${indices.lsi.toStringAsFixed(2)} (positive = scaling tendency).';
        if (ctData?.temperature == null) {
           detail += '\n\n*Note: Temperature not provided; defaulted to 35°C. For more accurate LSI, include Temperature in upload.';
        }
      }
      recs.add(Recommendation(
        title: "High Scaling Risk",
        description: detail,
        priority: risk.scalingRisk == RiskLevel.critical ? RecommendationPriority.critical : RecommendationPriority.high,
        category: RecommendationCategory.chemicalDosing,
        actionSteps: ["Check scale inhibitor dosing pump calibration", "Increase dosage by 10-15%", "Re-test LSI within 24 hours", "Inspect heat exchangers for deposits"],
      ));
    }

    // Alert 2: Elevated Corrosion Risk
    if (risk.corrosionRisk == RiskLevel.high || risk.corrosionRisk == RiskLevel.critical) {
      String detail = 'Corrosion risk score: ${risk.corrosionScore.toStringAsFixed(0)}%.';
      if (ctData != null) {
        detail += ' Zinc=${ctData.zinc.value} ppm (optimal: 1.5-2.5).';
        detail += ' Chloride=${ctData.chloride.value} ppm.';
      }
      if (indices != null) {
        detail += ' RSI=${indices.rsi.toStringAsFixed(2)} (>7.5 = corrosive).';
        if (indices.larsonSkold != null) {
          detail += ' Larson-Skold=${indices.larsonSkold!.toStringAsFixed(2)} (>1.2 = aggressive).';
          if (indices.sulfateEstimated) {
             detail += '\n\n*Note: Sulfate not measured; estimated as 50% of Chloride. Measure Sulfate directly for precise corrosion assessment.';
          }
        }
      }
      recs.add(Recommendation(
        title: "Elevated Corrosion Risk",
        description: detail,
        priority: risk.corrosionRisk == RiskLevel.critical ? RecommendationPriority.critical : RecommendationPriority.high,
        category: RecommendationCategory.chemicalDosing,
        actionSteps: ["Inspect coupon racks for pitting", "Review azole/zinc inhibitor levels", "Monitor iron trends for corrosion products", "Check blowdown rate"],
      ));
    }

    // Alert 3: Fouling/Deposition
    if (risk.foulingRisk == RiskLevel.high || risk.foulingRisk == RiskLevel.critical) {
      String detail = 'Fouling risk score: ${risk.foulingScore.toStringAsFixed(0)}%.';
      if (ctData != null) {
        detail += ' Iron=${ctData.iron.value} ppm (optimal: <0.3).';
        detail += ' Phosphates=${ctData.phosphates.value} ppm (optimal: 12-18).';
      }
      recs.add(Recommendation(
        title: "Fouling/Deposition Alert",
        description: detail,
        priority: risk.foulingRisk == RiskLevel.critical ? RecommendationPriority.critical : RecommendationPriority.high,
        category: RecommendationCategory.equipmentMaintenance,
        actionSteps: ["Check strainers and filters", "Review dispersant dosage", "Inspect basin for sludge accumulation", "Schedule macro biocide shock"],
      ));
    }

    // Alert 4: De-chlorination Failure (always critical)
    if (roData != null && roData.freeChlorine.value > 0.1) {
      recs.add(Recommendation(
        title: "De-chlorination Failure",
        description: 'Free chlorine=${roData.freeChlorine.value} ppm (threshold: 0.1 ppm). Chlorine >0.1 ppm causes irreversible oxidative damage to polyamide RO membranes.',
        priority: RecommendationPriority.critical,
        category: RecommendationCategory.operationalAdjustments,
        actionSteps: ["Check SBS (sodium bisulfite) dosing system immediately", "Inspect carbon filter for breakthrough", "Shut down RO if chlorine >0.5 ppm", "Verify ORP sensor calibration"],
      ));
    }

    // Alert 5: pH Deviation
    if (ctData != null && (ctData.ph.value < 6.5 || ctData.ph.value > 9.0)) {
      final direction = ctData.ph.value < 6.5 ? 'Low' : 'High';
      final consequence = ctData.ph.value < 6.5 
          ? 'Low pH accelerates corrosion of carbon steel and dissolves protective passivation films.'
          : 'High pH reduces CO₂ solubility, promoting calcium carbonate precipitation (scaling).';
      recs.add(Recommendation(
        title: "$direction pH Deviation",
        description: 'pH=${ctData.ph.value} (optimal: 7.0-8.5). $consequence',
        priority: RecommendationPriority.high,
        category: RecommendationCategory.chemicalDosing,
        actionSteps: ["Check acid/base dosing pump", "Verify pH probe calibration", "Review makeup water pH", "Adjust chemical feed rates"],
      ));
    }

    // Alert 6: High Conductivity
    if (ctData != null && ctData.conductivity.value > 3000) {
      recs.add(Recommendation(
        title: "High Conductivity",
        description: 'Conductivity=${ctData.conductivity.value} µS/cm (threshold: 3000). High conductivity indicates excessive mineral concentration, increasing scaling and corrosion risk.',
        priority: RecommendationPriority.medium,
        category: RecommendationCategory.operationalAdjustments,
        actionSteps: ["Increase blowdown rate", "Check makeup water quality", "Verify conductivity controller setpoint", "Review cycles of concentration target"],
      ));
    }

    return recs;
  }

  static RiskLevel _getRiskLevel(double score) {
    if (score < 20) return RiskLevel.low;
    if (score < 50) return RiskLevel.medium;
    if (score < 80) return RiskLevel.high;
    return RiskLevel.critical;
  }

  static double log10(num x) => log(x) / ln10;
}
