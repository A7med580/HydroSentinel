import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../services/state_provider.dart';
import '../../models/assessment_models.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ALERTS & RECOMMENDATIONS')),
      body: state.recommendations.isEmpty
          ? const Center(child: Text('No active alerts. System is stable.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppStyles.paddingM),
              itemCount: state.recommendations.length,
              itemBuilder: (context, index) {
                final rec = state.recommendations[index];
                return _buildRecommendationCard(rec);
              },
            ),
    );
  }

  Widget _buildRecommendationCard(Recommendation rec) {
    Color priorityColor = _getPriorityColor(rec.priority);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: priorityColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: priorityColor,
              child: Icon(_getCategoryIcon(rec.category), color: Colors.white, size: 20),
            ),
            title: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(rec.category.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ')),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.priority.name.toUpperCase(),
                style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppStyles.paddingM),
            child: Text(rec.description, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: AppStyles.paddingM),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppStyles.paddingM),
            child: Text('REQUIRED ACTIONS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          ...rec.actionSteps.map((step) => Padding(
            padding: const EdgeInsets.fromLTRB(AppStyles.paddingM, 4, AppStyles.paddingM, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(step, style: const TextStyle(fontSize: 13))),
              ],
            ),
          )),
          const SizedBox(height: AppStyles.paddingM),
        ],
      ),
    );
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.critical: return AppColors.riskCritical;
      case RecommendationPriority.high: return AppColors.riskHigh;
      case RecommendationPriority.medium: return AppColors.riskMedium;
      case RecommendationPriority.low: return AppColors.riskLow;
    }
  }

  IconData _getCategoryIcon(RecommendationCategory category) {
    switch (category) {
      case RecommendationCategory.chemicalDosing: return Icons.biotech;
      case RecommendationCategory.operationalAdjustments: return Icons.settings;
      case RecommendationCategory.equipmentMaintenance: return Icons.build;
      case RecommendationCategory.systemUpgrades: return Icons.upgrade;
    }
  }
}
