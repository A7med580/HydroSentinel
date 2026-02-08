import 'package:flutter/material.dart';
import '../app_styles.dart';

/// Trend direction for KPI indicators
enum TrendDirection { up, down, neutral }

/// A professional KPI Card widget for displaying metrics
/// Part of the Industrial SaaS design system
class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final String? subtitle;
  final TrendDirection trend;
  final double? trendValue;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.trend = TrendDirection.neutral,
    this.trendValue,
    this.valueColor,
    this.icon,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with title and icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null)
                  Icon(icon, size: 18, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: AppStyles.paddingS),
            
            // Value row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            
            // Trend and subtitle row
            if (trendValue != null || subtitle != null) ...[
              const SizedBox(height: AppStyles.paddingS),
              Row(
                children: [
                  if (trendValue != null) ...[
                    _buildTrendIndicator(),
                    const SizedBox(width: AppStyles.paddingS),
                  ],
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    Color trendColor;
    IconData trendIcon;
    
    switch (trend) {
      case TrendDirection.up:
        trendColor = AppColors.success;
        trendIcon = Icons.trending_up;
        break;
      case TrendDirection.down:
        trendColor = AppColors.error;
        trendIcon = Icons.trending_down;
        break;
      case TrendDirection.neutral:
        trendColor = AppColors.textMuted;
        trendIcon = Icons.trending_flat;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.paddingXS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 2),
          Text(
            '${trendValue! >= 0 ? '+' : ''}${trendValue!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: trendColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact KPI Card variant for grid layouts
class KPICardCompact extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  const KPICardCompact({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: color ?? AppColors.primary),
            const SizedBox(height: AppStyles.paddingS),
          ],
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
