import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/assessment_models.dart' as am;
import '../../../models/chemistry_models.dart';
import '../../../services/calculation_engine.dart';
// import 'factory_providers.dart'; // Deprecated V1 provider
// import '../domain/report_entity.dart'; // Deprecated V1 entity

/// Replicates the generic SystemState but scoped to a single Factory
class FactorySystemState {
  final bool isLoading;
  final am.SystemHealth? health;
  final am.RiskAssessment? riskAssessment;
  final am.ROProtectionAssessment? roAssessment;
  final CoolingTowerData? coolingTowerData;
  final ROData? roData;
  final List<am.Recommendation> recommendations;

  FactorySystemState({
    required this.isLoading,
    this.health,
    this.riskAssessment,
    this.roAssessment,
    this.coolingTowerData,
    this.roData,
    this.recommendations = const [],
  });

  factory FactorySystemState.loading() => FactorySystemState(isLoading: true);
  
  factory FactorySystemState.empty() => FactorySystemState(isLoading: false);
}

/// Computes the System State for a specific factory based on its latest V2 measurement
/// Replaces the legacy V1 'reports' table based implementation.
final factoryStateProvider = StreamProvider.family<FactorySystemState, String>((ref, factoryId) {
  // Query measurements_v2 directly via Supabase stream
  // This ensures real-time updates when new data is merged
  return Supabase.instance.client
      .from('measurements_v2')
      .stream(primaryKey: ['id'])
      .eq('factory_id', factoryId)
      .order('start_date', ascending: false)
      .limit(1)
      .map((List<Map<String, dynamic>> data) {
        if (data.isEmpty) {
          return FactorySystemState.empty();
        }

        final latestMeasurement = data.first;
        final measurementData = latestMeasurement['data'] as Map<String, dynamic>? ?? {};
        final startDate = DateTime.parse(latestMeasurement['start_date']);

        // 1. Reconstruct Cooling Tower Data
        // Helper function to safely extract double
        double val(String key) {
          final v = measurementData[key];
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0.0;
          return 0.0;
        }

        // Helper to validate parameter
        DataQuality check(double val, double min, double max) {
          return CalculationEngine.validateParameter(val, min, max);
        }

        final ctData = CoolingTowerData(
          ph: WaterParameter(
            name: 'pH', value: val('ph'), unit: 'pH', 
            optimalMin: 7.0, optimalMax: 8.5, quality: check(val('ph'), 7.0, 8.5)),
          alkalinity: WaterParameter(
            name: 'Alkalinity', value: val('alkalinity'), unit: 'ppm', 
            optimalMin: 100, optimalMax: 500, quality: check(val('alkalinity'), 100, 500)),
          conductivity: WaterParameter(
            name: 'Conductivity', value: val('conductivity'), unit: 'µS/cm', 
            optimalMin: 500, optimalMax: 3000, quality: check(val('conductivity'), 500, 3000)),
          totalHardness: WaterParameter(
            name: 'Total Hardness', value: val('hardness'), unit: 'ppm', 
            optimalMin: 50, optimalMax: 400, quality: check(val('hardness'), 50, 400)),
          chloride: WaterParameter(
            name: 'Chloride', value: val('chloride'), unit: 'ppm', 
            optimalMin: 0, optimalMax: 250, quality: check(val('chloride'), 0, 250)),
          zinc: WaterParameter(
            name: 'Zinc', value: val('zinc'), unit: 'ppm', 
            optimalMin: 0.5, optimalMax: 2.0, quality: check(val('zinc'), 0.5, 2.0)),
          iron: WaterParameter(
            name: 'Iron', value: val('iron'), unit: 'ppm', 
            optimalMin: 0, optimalMax: 0.5, quality: check(val('iron'), 0, 0.5)),
          phosphates: WaterParameter(
            name: 'Phosphates', value: val('phosphates'), unit: 'ppm', 
            optimalMin: 5, optimalMax: 15, quality: check(val('phosphates'), 5, 15)),
          
          // Optional params (Phase 1)
          temperature: (measurementData['temperature'] is num && (measurementData['temperature'] as num) > 0)
              ? WaterParameter(name: 'Temperature', value: (measurementData['temperature'] as num).toDouble(), unit: '°C', optimalMin: 20, optimalMax: 45)
              : null,
          sulfate: (measurementData['sulfate'] is num && (measurementData['sulfate'] as num) > 0)
              ? WaterParameter(name: 'Sulfate', value: (measurementData['sulfate'] as num).toDouble(), unit: 'ppm', optimalMin: 0, optimalMax: 500)
              : null,
          
          timestamp: startDate,
        );

        // 2. Reconstruct RO Data (if available)
        ROData? roData;
        if (measurementData.containsKey('free_chlorine') || measurementData.containsKey('silica')) {
          roData = ROData(
            freeChlorine: WaterParameter(
              name: 'Free Chlorine', value: val('free_chlorine'), unit: 'ppm', 
              optimalMin: 0, optimalMax: 0.1, quality: check(val('free_chlorine'), 0, 0.1)),
            silica: WaterParameter(
              name: 'Silica', value: val('silica'), unit: 'ppm', 
              optimalMin: 0, optimalMax: 150, quality: check(val('silica'), 0, 150)),
            roConductivity: WaterParameter(
              name: 'RO Conductivity', value: val('ro_conductivity'), unit: 'µS/cm', 
              optimalMin: 0, optimalMax: 50, quality: check(val('ro_conductivity'), 0, 50)),
            timestamp: startDate,
          );
        }

        // 3. Run Calculation Engine (Live)
        // We recalculate instead of trusting the DB indices column to ensure we use the LATEST logic 
        // (including all Phase 1 scientific fixes)
        final indices = CalculationEngine.calculateIndices(ctData);
        final riskAssessment = CalculationEngine.assessRisk(indices, ctData, roData: roData);
        
        am.ROProtectionAssessment? roAssessment;
        if (roData != null) {
          roAssessment = CalculationEngine.assessRO(roData);
        }
        
        final systemHealth = CalculationEngine.calculateHealth(riskAssessment, roAssessment, ctData: ctData, roData: roData);
        
        // 4. Generate Recommendations
        final recommendations = CalculationEngine.generateRecommendations(
            riskAssessment, systemHealth, roData, ctData: ctData, indices: indices);

        return FactorySystemState(
          isLoading: false,
          health: systemHealth,
          riskAssessment: riskAssessment,
          roAssessment: roAssessment,
          coolingTowerData: ctData,
          roData: roData,
          recommendations: recommendations,
        );
      });
});
