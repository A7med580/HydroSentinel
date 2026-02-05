import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../services/state_provider.dart';

class IndicesScreen extends ConsumerWidget {
  const IndicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemProvider);

    if (state.isLoading || state.indices == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final indices = state.indices!;

    return Scaffold(
      appBar: AppBar(title: const Text('CALCULATED INDICES')),
      body: ListView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        children: [
          _buildIndexCard(
            'Langelier Saturation Index (LSI)',
            indices.lsi,
            _getLsiInterpretation(indices.lsi),
            'Predicts the calcium carbonate stability of water.',
          ),
          _buildIndexCard(
            'Ryznar Stability Index (RSI)',
            indices.rsi,
            _getRsiInterpretation(indices.rsi),
            'Indicates the scaling or corrosive tendency of water.',
          ),
          _buildIndexCard(
            'Puckorius Scaling Index (PSI)',
            indices.psi,
            _getPsiInterpretation(indices.psi),
            'Modified index for better prediction in cooling water.',
          ),
          _buildIndexCard(
            'Larson-Skold Ratio',
            indices.larsonSkold,
            _getLarsonInterpretation(indices.larsonSkold),
            'Ratio of corrosive ions to inhibitory ions.',
          ),
          _buildIndexCard(
            'Cycles of Concentration (CoC)',
            indices.coc,
            'Target: 4.0 - 6.0',
            'Number of times makeup water has been concentrated.',
          ),
          _buildIndexGrid([
            _IndexSimple('Stiff-Davis', indices.stiffDavis),
            _IndexSimple('Adjusted PSI', indices.adjustedPsi),
            _IndexSimple('TDS Est.', indices.tdsEstimation),
            _IndexSimple('Cl/SO4 Ratio', indices.chlorideSulfateRatio),
          ]),
        ],
      ),
    );
  }

  Widget _buildIndexCard(String title, double value, String interpretation, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            interpretation,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: interpretation.contains('Scale') ? AppColors.riskHigh : AppColors.riskLow,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildIndexGrid(List<_IndexSimple> indexes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: AppStyles.paddingS,
        crossAxisSpacing: AppStyles.paddingS,
      ),
      itemCount: indexes.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(AppStyles.paddingS),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(indexes[index].name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(
                indexes[index].value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLsiInterpretation(double lsi) {
    if (lsi > 2.0) return 'Severe Scale Forming';
    if (lsi > 0.5) return 'Slightly Scale Forming';
    if (lsi > -0.5) return 'Balanced / Neutral';
    if (lsi > -2.0) return 'Slightly Corrosive';
    return 'Severe Corrosive';
  }

  String _getRsiInterpretation(double rsi) {
    if (rsi < 6.0) return 'Scale Forming';
    if (rsi < 7.0) return 'Neutral';
    if (rsi < 8.0) return 'Slightly Corrosive';
    return 'Severe Corrosive';
  }

  String _getPsiInterpretation(double psi) {
    if (psi < 6.0) return 'Scale Forming';
    return 'Non-Scaling / Balanced';
  }

  String _getLarsonInterpretation(double ratio) {
    if (ratio < 0.2) return 'Low Corrosion Risk';
    if (ratio < 1.2) return 'Moderate Corrosion Risk';
    return 'High Corrosion Risk';
  }
}

class _IndexSimple {
  final String name;
  final double value;
  _IndexSimple(this.name, this.value);
}
