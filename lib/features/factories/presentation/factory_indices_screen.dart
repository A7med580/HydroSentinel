import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import '../../../models/chemistry_models.dart';
import '../../../models/assessment_models.dart';
import '../../../services/calculation_engine.dart';
import 'factory_state_provider.dart';

class FactoryIndicesScreen extends ConsumerWidget {
  final String factoryId;

  const FactoryIndicesScreen({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(factoryStateProvider(factoryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('CALCULATED INDICES'),
        automaticallyImplyLeading: false,
      ),
      body: stateAsync.when(
        data: (state) {
          if (state.coolingTowerData == null) {
            return const Center(
              child: Text(
                'No data available.\nSync to fetch reports.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Calculate indices from state data using CalculationEngine
          final ctData = state.coolingTowerData!;
          final indices = CalculationEngine.calculateIndices(ctData);

          return ListView(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            children: [
              _buildIndexCard(
                'Langelier Saturation Index (LSI)',
                indices.lsi.toStringAsFixed(2),
                _getLSIInterpretation(indices.lsi),
                _getLSIColor(indices.lsi),
                'Predicts the calcium carbonate stability of water.',
              ),
              _buildIndexCard(
                'Ryznar Stability Index (RSI)',
                indices.rsi.toStringAsFixed(2),
                _getRSIInterpretation(indices.rsi),
                _getRSIColor(indices.rsi),
                'Indicates the scaling or corrosive tendency of water.',
              ),
              _buildIndexCard(
                'Puckorius Scaling Index (PSI)',
                indices.psi.toStringAsFixed(2),
                _getPSIInterpretation(indices.psi),
                _getPSIColor(indices.psi),
                'Modified index for better prediction in cooling water.',
              ),
              _buildIndexCard(
                'Larson-Skold Ratio',
                (indices.larsonSkold ?? 0.0).toStringAsFixed(2),
                _getLarsonInterpretation(indices.larsonSkold ?? 0.0),
                _getLarsonColor(indices.larsonSkold ?? 0.0),
                'Ratio of corrosive ions to inhibitory ions.',
              ),
              _buildIndexCard(
                'Cycles of Concentration (CoC)',
                indices.coc.toStringAsFixed(2),
                'Target: 4.0 - 6.0',
                AppColors.primary,
                'Number of times makeup water has been concentrated.',
              ),
              const SizedBox(height: 16),
              _buildFooterStats(indices),
            ],
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildIndexCard(
    String title,
    String value,
    String interpretation,
    Color color,
    String description,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            interpretation,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStats(CalculatedIndices indices) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatBox(
                'Stiff-Davis',
                indices.lsi.toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatBox(
                'Adjusted PSI',
                indices.psi.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatBox(
                'TDS Est.',
                indices.tdsEstimation.toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatBox(
                'Cl/SO4 Ratio',
                indices.chlorideSulfateRatio.toStringAsFixed(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // LSI Interpretation
  String _getLSIInterpretation(double lsi) {
    if (lsi > 2.0) return 'Severe Scale Forming';
    if (lsi > 0.5) return 'Slightly Scale Forming';
    if (lsi > -0.5) return 'Balanced / Neutral';
    if (lsi > -2.0) return 'Slightly Corrosive';
    return 'Severe Corrosive';
  }

  Color _getLSIColor(double lsi) {
    if (lsi.abs() <= 0.5) return AppColors.riskLow;
    if (lsi.abs() <= 2.0) return AppColors.riskMedium;
    return AppColors.riskHigh;
  }

  // RSI Interpretation
  String _getRSIInterpretation(double rsi) {
    if (rsi < 6.0) return 'Scale Forming';
    if (rsi < 7.0) return 'Neutral';
    if (rsi < 8.0) return 'Slightly Corrosive';
    return 'Severe Corrosive';
  }

  Color _getRSIColor(double rsi) {
    if (rsi < 6.0 || rsi >= 8.0) return AppColors.riskHigh;
    if (rsi >= 6.0 && rsi < 7.0) return AppColors.riskLow;
    return AppColors.riskMedium;
  }

  // PSI Interpretation
  String _getPSIInterpretation(double psi) {
    if (psi < 6.0) return 'Scale Forming';
    return 'Non-Scaling / Balanced';
  }

  Color _getPSIColor(double psi) {
    return psi < 6.0 ? AppColors.riskHigh : AppColors.riskLow;
  }

  // Larson Ratio Interpretation
  String _getLarsonInterpretation(double ratio) {
    if (ratio > 1.2) return 'High Corrosion Risk';
    if (ratio > 0.8) return 'Moderate Risk';
    return 'Low Corrosion Risk';
  }

  Color _getLarsonColor(double ratio) {
    if (ratio > 1.2) return AppColors.riskCritical;
    if (ratio > 0.8) return AppColors.riskMedium;
    return AppColors.riskLow;
  }
}
