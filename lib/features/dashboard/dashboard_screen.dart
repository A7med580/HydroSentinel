import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/period_selector.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/aggregated_data_provider.dart';
import '../../models/assessment_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final asyncData = ref.watch(aggregatedDataProvider);

    return asyncData.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('Error: $err'),
        ),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No measurement data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload an Excel file from the Factories screen',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        
        return _buildDashboardContent(context, ref, data, selectedPeriod);
      },
    );
  }
  
  Widget _buildDashboardContent(BuildContext context, WidgetRef ref, AggregatedData data, TimePeriod selectedPeriod) {


    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              title: const Text('Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            
            // Content
            SliverPadding(
              padding: const EdgeInsets.all(AppStyles.paddingM),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Period Selector with data count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            '${data.measurementCount} measurements',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      PeriodSelector(
                        selectedPeriod: selectedPeriod,
                        onPeriodChanged: (period) {
                          ref.read(selectedPeriodProvider.notifier).setPeriod(period);
                        },
                        showLabels: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppStyles.paddingL),

                  // System Health Card
                  _buildHealthCard(data.health),
                  const SizedBox(height: AppStyles.paddingM),

                  // Risk KPIs Grid
                  Text(
                    'Risk Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppStyles.paddingM),
                  _buildRiskGrid(data.risk),
                  const SizedBox(height: AppStyles.paddingL),

                  // RO Protection (if available)
                  if (data.roAssessment != null) ...[
                    Text(
                      'RO Protection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppStyles.paddingM),
                    _buildROGrid(data.roAssessment!),
                    const SizedBox(height: AppStyles.paddingL),
                  ],

                  // Indices
                  Text(
                    'Calculated Indices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppStyles.paddingM),
                  _buildIndicesGrid(data.indices),
                  const SizedBox(height: AppStyles.paddingL),

                  // Active Alerts
                  _buildAlertsSection(context, data.recommendations),
                  const SizedBox(height: AppStyles.paddingXL),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(SystemHealth health) {
    final color = _getHealthColor(health.overallScore);
    
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Health Score Circle
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: health.overallScore / 100,
                    strokeWidth: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      health.overallScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'SCORE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppStyles.paddingL),
          
          // Health Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'System Health',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppStyles.paddingS),
                    StatusBadge(
                      label: health.status,
                      type: _getStatusType(health.overallScore),
                    ),
                  ],
                ),
                const SizedBox(height: AppStyles.paddingS),
                Text(
                  _getHealthMessage(health.status),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (health.keyIssues.isNotEmpty) ...[
                  const SizedBox(height: AppStyles.paddingS),
                  Text(
                    '${health.keyIssues.length} issue${health.keyIssues.length > 1 ? 's' : ''} detected',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGrid(RiskAssessment risk) {
    return Row(
      children: [
        Expanded(
          child: KPICardCompact(
            label: 'Scaling',
            value: risk.scalingScore.toStringAsFixed(0),
            color: _getRiskColor(risk.scalingRisk),
            icon: Icons.layers_outlined,
          ),
        ),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: KPICardCompact(
            label: 'Corrosion',
            value: risk.corrosionScore.toStringAsFixed(0),
            color: _getRiskColor(risk.corrosionRisk),
            icon: Icons.bolt_outlined,
          ),
        ),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: KPICardCompact(
            label: 'Fouling',
            value: risk.foulingScore.toStringAsFixed(0),
            color: _getRiskColor(risk.foulingRisk),
            icon: Icons.bubble_chart_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildROGrid(ROProtectionAssessment ro) {
    return Row(
      children: [
        Expanded(
          child: KPICard(
            title: 'Oxidation Risk',
            value: ro.oxidationRiskScore.toStringAsFixed(0),
            unit: '%',
            valueColor: _getInvertedScoreColor(ro.oxidationRiskScore),
            icon: Icons.warning_amber_outlined,
          ),
        ),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: KPICard(
            title: 'Silica Scaling',
            value: ro.silicaScalingRiskScore.toStringAsFixed(0),
            unit: '%',
            valueColor: _getInvertedScoreColor(ro.silicaScalingRiskScore),
            icon: Icons.grain_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicesGrid(CalculatedIndices indices) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppStyles.paddingS,
      crossAxisSpacing: AppStyles.paddingS,
      childAspectRatio: 1.1,
      children: [
        KPICardCompact(
          label: 'LSI',
          value: indices.lsi.toStringAsFixed(2),
          color: _getIndexColor(indices.lsi),
        ),
        KPICardCompact(
          label: 'RSI',
          value: indices.rsi.toStringAsFixed(2),
          color: _getIndexColor(indices.rsi - 6), // Center around 6
        ),
        KPICardCompact(
          label: 'PSI',
          value: indices.psi.toStringAsFixed(2),
          color: _getIndexColor(indices.psi - 6), // Center around 6
        ),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context, List<Recommendation> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Alerts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (recommendations.isNotEmpty)
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: AppStyles.paddingM),
        if (recommendations.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppStyles.paddingL),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 24,
                ),
                const SizedBox(width: AppStyles.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Clear',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'No active alerts. System parameters within range.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...recommendations.take(3).map((r) => _buildAlertCard(r)),
      ],
    );
  }

  Widget _buildAlertCard(Recommendation r) {
    final color = r.priority == RecommendationPriority.critical
        ? AppColors.error
        : r.priority == RecommendationPriority.high
            ? AppColors.warning
            : AppColors.info;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingS),
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppStyles.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    if (score >= 40) return AppColors.riskHigh;
    return AppColors.error;
  }

  StatusType _getStatusType(double score) {
    if (score >= 80) return StatusType.success;
    if (score >= 60) return StatusType.warning;
    return StatusType.error;
  }

  String _getHealthMessage(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return 'System Operating Optimally';
      case 'good':
        return 'System Running Well';
      case 'fair':
        return 'Monitor Closely';
      case 'poor':
        return 'Attention Required';
      default:
        return 'Critical Intervention Needed';
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.error;
    }
  }

  Color _getInvertedScoreColor(double score) {
    // Lower is better for risk scores
    if (score <= 20) return AppColors.success;
    if (score <= 50) return AppColors.warning;
    return AppColors.error;
  }

  Color _getIndexColor(double value) {
    // Near zero is good for LSI
    if (value.abs() <= 0.5) return AppColors.success;
    if (value.abs() <= 1.5) return AppColors.warning;
    return AppColors.error;
  }
}
