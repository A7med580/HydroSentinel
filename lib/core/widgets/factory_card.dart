import 'package:flutter/material.dart';
import '../app_styles.dart';
import 'status_badge.dart';

/// A professional factory card widget matching the Figma design
/// Part of the Industrial SaaS design system
class FactoryCard extends StatelessWidget {
  final String name;
  final String status;
  final DateTime? lastSyncAt;
  final int? alertCount;
  final double? healthScore;
  final VoidCallback? onTap;

  const FactoryCard({
    super.key,
    required this.name,
    required this.status,
    this.lastSyncAt,
    this.alertCount,
    this.healthScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Factory icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppStyles.borderRadiusS),
                  ),
                  child: Icon(
                    Icons.factory_outlined,
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppStyles.paddingM),
                
                // Name and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last sync: ${_formatDate(lastSyncAt)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status badge
                StatusBadge.fromFactoryStatus(status),
              ],
            ),
            
            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppStyles.paddingM),
              child: Divider(color: AppColors.border, height: 1),
            ),
            
            // Stats row
            Row(
              children: [
                // Health score
                if (healthScore != null) ...[
                  _buildStat(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Health',
                    value: '${healthScore!.toStringAsFixed(0)}%',
                    color: _getHealthColor(healthScore!),
                  ),
                  const SizedBox(width: AppStyles.paddingL),
                ],
                
                // Alert count
                if (alertCount != null) ...[
                  _buildStat(
                    icon: Icons.notifications_outlined,
                    label: 'Alerts',
                    value: alertCount.toString(),
                    color: alertCount! > 0 ? AppColors.warning : AppColors.textMuted,
                  ),
                ],
                
                const Spacer(),
                
                // Arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'good':
      case 'online':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'critical':
      case 'offline':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  Color _getHealthColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}
