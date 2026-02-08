import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hydrosentinel/core/app_styles.dart';
import 'package:hydrosentinel/models/chemistry_models.dart';
import 'package:hydrosentinel/services/calculation_engine.dart';
import 'package:hydrosentinel/models/assessment_models.dart';
import 'factory_state_provider.dart';

class FactorySimulationScreen extends ConsumerStatefulWidget {
  final String factoryId;
  const FactorySimulationScreen({super.key, required this.factoryId});

  @override
  ConsumerState<FactorySimulationScreen> createState() => _FactorySimulationScreenState();
}

class _FactorySimulationScreenState extends ConsumerState<FactorySimulationScreen> {
  // Default fallbacks if no data exists
  double _simPh = 7.8;
  double _simAlk = 250.0;
  double _simHard = 320.0;
  double _simCond = 2400.0;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(factoryStateProvider(widget.factoryId));

    // Initialize values once data is loaded (and only once)
    if (!_initialized && stateAsync.hasValue) {
       final state = stateAsync.value!;
       if (state.coolingTowerData != null) {
          // Guard against "Empty" zero data which can crash the UI or confuse users
          // If all main params are 0, it likely failed. We check pH specifically.
          if (state.coolingTowerData!.ph.value > 0) {
              _simPh = state.coolingTowerData!.ph.value;
              _simAlk = state.coolingTowerData!.alkalinity.value;
              _simHard = state.coolingTowerData!.totalHardness.value;
              _simCond = state.coolingTowerData!.conductivity.value;
          }
       }
       _initialized = true;
    }

    // Recalculate based on simulated values
    final mockData = CoolingTowerData(
      ph: WaterParameter(name: 'pH', value: _simPh, unit: 'pH'),
      alkalinity: WaterParameter(name: 'Alkalinity', value: _simAlk, unit: 'ppm'),
      conductivity: WaterParameter(name: 'Conductivity', value: _simCond, unit: 'µS/cm'),
      totalHardness: WaterParameter(name: 'Total Hardness', value: _simHard, unit: 'ppm'),
      chloride: WaterParameter(name: 'Chloride', value: 250, unit: 'ppm'),
      zinc: WaterParameter(name: 'Zinc', value: 1.0, unit: 'ppm'),
      iron: WaterParameter(name: 'Iron', value: 0.1, unit: 'ppm'),
      phosphates: WaterParameter(name: 'Phosphates', value: 10, unit: 'ppm'),
      timestamp: DateTime.now(),
    );

    final indices = CalculationEngine.calculateIndices(mockData);
    final risk = CalculationEngine.assessRisk(indices, mockData);
    final health = CalculationEngine.calculateHealth(risk, null);

    return Scaffold(
      appBar: AppBar(title: const Text('WHAT-IF SIMULATION')),
      body: Column(
        children: [
          _buildSimulatedResults(health, indices, risk),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppStyles.paddingM),
              children: [
                _buildSlider('pH Level', _simPh, 3.0, 12.0, (val) => setState(() => _simPh = val)),
                _buildSlider('Alkalinity (ppm)', _simAlk, 50, 800, (val) => setState(() => _simAlk = val)),
                _buildSlider('Hardness (ppm)', _simHard, 20, 1000, (val) => setState(() => _simHard = val)),
                _buildSlider('Conductivity (µS)', _simCond, 200, 6000, (val) => setState(() => _simCond = val)),
                const SizedBox(height: AppStyles.paddingL),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () {
                    // Reset to real data (only if valid)
                    final state = stateAsync.value;
                    if (state?.coolingTowerData != null && state!.coolingTowerData!.ph.value > 0) {
                      setState(() {
                         _simPh = state.coolingTowerData!.ph.value;
                         _simAlk = state.coolingTowerData!.alkalinity.value;
                         _simHard = state.coolingTowerData!.totalHardness.value;
                         _simCond = state.coolingTowerData!.conductivity.value;
                      });
                    } else {
                       // Defaults
                        setState(() {
                          _simPh = 7.8;
                          _simAlk = 250.0;
                          _simHard = 320.0;
                          _simCond = 2400.0;
                        });
                    }
                  },
                  child: const Text('RESET TO LATEST DATA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedResults(SystemHealth health, CalculatedIndices indices, RiskAssessment risk) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppStyles.paddingM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('HEALTH', health.overallScore.toStringAsFixed(0), _getScoreColor(health.overallScore)),
              _buildStat('LSI', indices.lsi.toStringAsFixed(2), AppColors.primary),
              _buildStat('SCALING', '${risk.scalingScore.toStringAsFixed(0)}%', _getRiskColor(risk.scalingRisk)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'INTERPRETATION: ${health.status.toUpperCase()}',
            style: TextStyle(fontWeight: FontWeight.bold, color: _getScoreColor(health.overallScore)),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value.toStringAsFixed(label == 'pH Level' ? 2 : 0), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 100,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score > 80) return AppColors.riskLow;
    if (score > 60) return AppColors.riskMedium;
    if (score > 40) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return AppColors.riskLow;
      case RiskLevel.medium: return AppColors.riskMedium;
      case RiskLevel.high: return AppColors.riskHigh;
      case RiskLevel.critical: return AppColors.riskCritical;
    }
    return AppColors.riskCritical;
  }
}
