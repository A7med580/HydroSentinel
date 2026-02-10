import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chemistry_models.dart';
import '../models/assessment_models.dart';
import 'calculation_engine.dart';

class SystemState {
  final CoolingTowerData? coolingTowerData;
  final ROData? roData;
  final CalculatedIndices? indices;
  final RiskAssessment? riskAssessment;
  final ROProtectionAssessment? roAssessment;
  final SystemHealth? health;
  final List<Recommendation> recommendations;
  final bool isLoading;

  SystemState({
    this.coolingTowerData,
    this.roData,
    this.indices,
    this.riskAssessment,
    this.roAssessment,
    this.health,
    this.recommendations = const [],
    this.isLoading = false,
  });

  SystemState copyWith({
    CoolingTowerData? coolingTowerData,
    ROData? roData,
    CalculatedIndices? indices,
    RiskAssessment? riskAssessment,
    ROProtectionAssessment? roAssessment,
    SystemHealth? health,
    List<Recommendation>? recommendations,
    bool? isLoading,
  }) {
    return SystemState(
      coolingTowerData: coolingTowerData ?? this.coolingTowerData,
      roData: roData ?? this.roData,
      indices: indices ?? this.indices,
      riskAssessment: riskAssessment ?? this.riskAssessment,
      roAssessment: roAssessment ?? this.roAssessment,
      health: health ?? this.health,
      recommendations: recommendations ?? this.recommendations,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SystemNotifier extends Notifier<SystemState> {
  @override
  SystemState build() {
    return _generateMockInitialState();
  }

  void updateData(CoolingTowerData? ct, ROData? ro) {
    state = state.copyWith(isLoading: true);
    
    CalculatedIndices? indices;
    RiskAssessment? risk;
    ROProtectionAssessment? roAss;
    SystemHealth? health;
    List<Recommendation> recs = [];

    if (ct != null) {
      indices = CalculationEngine.calculateIndices(ct);
      risk = CalculationEngine.assessRisk(indices, ct, roData: ro);
    }

    if (ro != null) {
      roAss = CalculationEngine.assessRO(ro);
    }

    if (risk != null) {
      health = CalculationEngine.calculateHealth(risk, roAss, ctData: ct, roData: ro);
      recs = CalculationEngine.generateRecommendations(risk, health, ro, ctData: ct, indices: indices);
    }

    state = state.copyWith(
      coolingTowerData: ct,
      roData: ro,
      indices: indices,
      riskAssessment: risk,
      roAssessment: roAss,
      health: health,
      recommendations: recs,
      isLoading: false,
    );
  }

  SystemState _generateMockInitialState() {
    final ct = CoolingTowerData(
      ph: WaterParameter(name: 'pH', value: 7.8, unit: 'pH', optimalMin: 7.0, optimalMax: 8.5),
      alkalinity: WaterParameter(name: 'Alkalinity', value: 250.0, unit: 'ppm', optimalMin: 100, optimalMax: 500),
      conductivity: WaterParameter(name: 'Conductivity', value: 2400.0, unit: 'µS/cm', optimalMin: 500, optimalMax: 3000),
      totalHardness: WaterParameter(name: 'Total Hardness', value: 320.0, unit: 'ppm', optimalMin: 50, optimalMax: 400),
      chloride: WaterParameter(name: 'Chloride', value: 450.0, unit: 'ppm', optimalMin: 0, optimalMax: 250),
      zinc: WaterParameter(name: 'Zinc', value: 1.2, unit: 'ppm', optimalMin: 0.5, optimalMax: 2.0),
      iron: WaterParameter(name: 'Iron', value: 0.1, unit: 'ppm', optimalMin: 0, optimalMax: 0.5),
      phosphates: WaterParameter(name: 'Phosphates', value: 8.0, unit: 'ppm', optimalMin: 5, optimalMax: 15),
      timestamp: DateTime.now(),
    );

    final ro = ROData(
      freeChlorine: WaterParameter(name: 'Free Chlorine', value: 0.02, unit: 'ppm', optimalMin: 0, optimalMax: 0.1),
      silica: WaterParameter(name: 'Silica', value: 45.0, unit: 'ppm', optimalMin: 0, optimalMax: 150),
      roConductivity: WaterParameter(name: 'RO Conductivity', value: 15.0, unit: 'µS/cm', optimalMin: 0, optimalMax: 50),
      timestamp: DateTime.now(),
    );

    final indices = CalculationEngine.calculateIndices(ct);
    final risk = CalculationEngine.assessRisk(indices, ct, roData: ro);
    final roAss = CalculationEngine.assessRO(ro);
    final health = CalculationEngine.calculateHealth(risk, roAss, ctData: ct, roData: ro);
    final recs = CalculationEngine.generateRecommendations(risk, health, ro, ctData: ct, indices: indices);

    return SystemState(
      coolingTowerData: ct,
      roData: ro,
      indices: indices,
      riskAssessment: risk,
      roAssessment: roAss,
      health: health,
      recommendations: recs,
      isLoading: false,
    );
  }
}

final systemProvider = NotifierProvider<SystemNotifier, SystemState>(() {
  return SystemNotifier();
});
