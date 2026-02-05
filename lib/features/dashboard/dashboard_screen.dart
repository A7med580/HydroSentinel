import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../services/state_provider.dart';
import '../../models/assessment_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemProvider);

    if (state.isLoading || state.health == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('HYDROSENTINEL DASHBOARD')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemStatusHeader(state.health!),
            const SizedBox(height: AppStyles.paddingL),
            Text('PRIMARY RISK FACTORS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppStyles.paddingM),
            _buildRiskGrid(state.riskAssessment!),
            const SizedBox(height: AppStyles.paddingL),
            if (state.roAssessment != null) ...[
              Text('REVERSE OSMOSIS PROTECTION', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppStyles.paddingM),
              _buildRORisks(state.roAssessment!),
              const SizedBox(height: AppStyles.paddingL),
            ],
            Text('ACTIVE ALERTS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppStyles.paddingM),
            _buildAlertPreview(state.recommendations),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusHeader(SystemHealth health) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: health.overallScore / 100,
                  strokeWidth: 10,
                  backgroundColor: AppColors.card,
                  color: _getScoreColor(health.overallScore),
                ),
              ),
              Text(
                health.overallScore.toStringAsFixed(0),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: AppStyles.paddingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SYSTEM HEALTH SCORE', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(
                  health.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(health.overallScore),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${health.keyIssues.length} active issues detected', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGrid(RiskAssessment assessment) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: AppStyles.paddingS,
      mainAxisSpacing: AppStyles.paddingS,
      children: [
        _buildRiskIndicator('SCALING', assessment.scalingScore, assessment.scalingRisk),
        _buildRiskIndicator('CORROSION', assessment.corrosionScore, assessment.corrosionRisk),
        _buildRiskIndicator('FOULING', assessment.foulingScore, assessment.foulingRisk),
      ],
    );
  }

  Widget _buildRiskIndicator(String label, double score, RiskLevel level) {
    Color color = _getRiskColor(level);
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingS),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            level.name.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRORisks(ROProtectionAssessment ro) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildROStat('OXIDATION', ro.oxidationRiskScore, flipped: true),
          _buildROStat('SILICA', ro.silicaScalingRiskScore, flipped: true),
          _buildROStat('MEMBRANE LIFE', ro.membraneLifeIndicator),
        ],
      ),
    );
  }

  Widget _buildROStat(String label, double score, {bool flipped = false}) {
    Color color = flipped ? _getScoreColor(100 - score) : _getScoreColor(score);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '${score.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildAlertPreview(List<Recommendation> recommendations) {
    if (recommendations.isEmpty) {
      return const Card(child: ListTile(title: Text('No active alerts. All parameters within range.')));
    }
    return Column(
      children: recommendations.take(2).map((r) => Card(
        color: AppColors.card,
        child: ListTile(
          leading: Icon(
            r.priority == RecommendationPriority.critical ? Icons.error : Icons.warning,
            color: r.priority == RecommendationPriority.critical ? AppColors.riskCritical : AppColors.riskHigh,
          ),
          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )).toList(),
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
  }
}
