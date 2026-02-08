import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydrosentinel/models/assessment_models.dart' as am;
import 'package:hydrosentinel/models/chemistry_models.dart';
import 'package:hydrosentinel/services/calculation_engine.dart';
import 'factory_providers.dart';
import 'package:hydrosentinel/features/factories/domain/report_entity.dart';
import 'dart:convert';

/// Replicates the generic SystemState but scoped to a single Factory
class FactorySystemState {
  final bool isLoading;
  final am.SystemHealth? health;
  final am.RiskAssessment? riskAssessment;
  final am.ROProtectionAssessment? roAssessment;
  final CoolingTowerData? coolingTowerData;
  final List<am.Recommendation> recommendations;

  FactorySystemState({
    required this.isLoading,
    this.health,
    this.riskAssessment,
    this.roAssessment,
    this.coolingTowerData,
    this.recommendations = const [],
  });

  factory FactorySystemState.loading() => FactorySystemState(isLoading: true);
  
  factory FactorySystemState.empty() => FactorySystemState(isLoading: false);
}

/// Computes the System State for a specific factory based on its latest report
final factoryStateProvider = Provider.family<AsyncValue<FactorySystemState>, String>((ref, factoryId) {
  final reportsAsync = ref.watch(factoryReportsProvider(factoryId));

  return reportsAsync.whenData((reports) {
    if (reports.isEmpty) {
      return FactorySystemState.empty();
    }

    // Use the latest report (reports are already ordered by analyzed_at desc in repo)
    final latestReport = reports.first;

    // Parse data from the report 'data' JSON
    // The report.data['cooling_tower'] is a string representation of the object (toString()), 
    // which is NOT ideal for parsing. Ideally we should have stored JSON.
    // However, looking at FactoryRepositoryImpl:
    // 'cooling_tower': ctData?.toString(), 

    // CRITICAL: We need to reconstruct the Models from the raw values stored in Top-Level Report Fields
    // OR we need to improve how we store data. 
    // Currently ReportEntity stores 'risk_scaling', 'risk_corrosion' directly.
    // But Dashboard needs `CoolingTowerData` to run `calculateIndices` if we want full fidelity.
    
    // WORKAROUND: We will reconstruct partial data from the specific risk scores we saved,
    // OR we rely on what we have. 
    // Since `CalculationEngine` requires `CoolingTowerData`, we might be blocked if we didn't save the raw parameters (pH, Conductivity etc) to DB.
    // Let's check `FactoryRepositoryImpl` again. It saves `risk_scaling`, `risk_corrosion` etc.
    // But `SystemState` needs `RiskAssessment` object.
    
    // We can reconstruct a RiskAssessment object directly from the saved scores!
    // We don't need to re-run calculation engine if we trust the saved scores.
    
    // Parse Cooling Tower Data first
    CoolingTowerData? ctData;
    if (latestReport.data['cooling_tower'] != null && latestReport.data['cooling_tower'] is Map) {
      try {
        final Map<String, dynamic> json = latestReport.data['cooling_tower'];
        ctData = CoolingTowerData(
          ph: WaterParameter(name: 'pH', value: (json['pH']['value'] as num).toDouble(), unit: 'pH'),
          alkalinity: WaterParameter(name: 'Total Alkalinity', value: (json['Alkalinity']['value'] as num).toDouble(), unit: 'ppm'),
          conductivity: WaterParameter(name: 'Conductivity', value: (json['Conductivity']['value'] as num).toDouble(), unit: 'µS/cm'),
          totalHardness: WaterParameter(name: 'Total Hardness', value: (json['Total Hardness']['value'] as num).toDouble(), unit: 'ppm'),
          chloride: WaterParameter(name: 'Chloride', value: (json['Chloride']['value'] as num).toDouble(), unit: 'ppm'),
          zinc: WaterParameter(name: 'Zinc', value: (json['Zinc']['value'] as num).toDouble(), unit: 'ppm'),
          iron: WaterParameter(name: 'Iron', value: (json['Iron']['value'] as num).toDouble(), unit: 'ppm'),
          phosphates: WaterParameter(name: 'Phosphates', value: (json['Phosphates']['value'] as num).toDouble(), unit: 'ppm'),
          timestamp: DateTime.parse(json['timestamp']),
        );
      } catch (e) {
        print('Error parsing factory CT data: $e');
      }
    }

    // Parse RO Data if available
    ROData? roData;
    if (latestReport.data['reverse_osmosis'] != null && latestReport.data['reverse_osmosis'] is Map) {
      try {
        final Map<String, dynamic> json = latestReport.data['reverse_osmosis'];
        roData = ROData(
          freeChlorine: WaterParameter(name: 'Free Chlorine', value: (json['Free Chlorine']['value'] as num).toDouble(), unit: 'ppm'),
          silica: WaterParameter(name: 'Silica', value: (json['Silica']['value'] as num).toDouble(), unit: 'ppm'),
          roConductivity: WaterParameter(name: 'RO Conductivity', value: (json['RO Conductivity']['value'] as num).toDouble(), unit: 'µS/cm'),
          timestamp: DateTime.parse(json['timestamp']),
        );
      } catch (e) {
        print('Error parsing factory RO data: $e');
      }
    }

    // RECALCULATE Risk & Health Live (Don't trust DB columns which might be old)
    am.RiskAssessment? riskAssessment;
    am.ROProtectionAssessment? roAssessment;
    am.SystemHealth? systemHealth;
    
    if (ctData != null) {
       final indices = CalculationEngine.calculateIndices(ctData);
       riskAssessment = CalculationEngine.assessRisk(indices, ctData);
       
       if (roData != null) {
          roAssessment = CalculationEngine.assessRO(roData);
       }
       
       systemHealth = CalculationEngine.calculateHealth(riskAssessment, roAssessment);
    } else {
       // Fallback to DB columns if JSON parse failed
       riskAssessment = am.RiskAssessment(
          scalingScore: (latestReport.data['risk_scaling'] as num?)?.toDouble() ?? 0.0,
          corrosionScore: (latestReport.data['risk_corrosion'] as num?)?.toDouble() ?? 0.0,
          foulingScore: (latestReport.data['risk_fouling'] as num?)?.toDouble() ?? 0.0,
          scalingRisk: _getRiskLevel((latestReport.data['risk_scaling'] as num?)?.toDouble() ?? 0.0),
          corrosionRisk: _getRiskLevel((latestReport.data['risk_corrosion'] as num?)?.toDouble() ?? 0.0),
          foulingRisk: _getRiskLevel((latestReport.data['risk_fouling'] as num?)?.toDouble() ?? 0.0),
          timestamp: latestReport.analyzedAt,
       );
       systemHealth = CalculationEngine.calculateHealth(riskAssessment, null);
    }
    
    // Recommendations need full data context, so we might return empty or generic ones
    final recommendations = <am.Recommendation>[]; 
    if (systemHealth != null) {
       // Use engine to generate recs if we have data
       if (ctData != null && riskAssessment != null) {
          recommendations.addAll(CalculationEngine.generateRecommendations(riskAssessment, systemHealth, null));
       }
    }

    return FactorySystemState(
      isLoading: false,
      health: systemHealth,
      riskAssessment: riskAssessment,
      roAssessment: null, 
      coolingTowerData: ctData,
      recommendations: recommendations,
    );
  });
});

// Extension to expose private helper if needed, or we just duplicate the helper since it's small
// Helper to determine risk level from score
am.RiskLevel _getRiskLevel(double score) {
  if (score < 20) return am.RiskLevel.low;
  if (score < 50) return am.RiskLevel.medium;
  if (score < 80) return am.RiskLevel.high;
  return am.RiskLevel.critical;
}
