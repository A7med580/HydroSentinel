import 'package:flutter/material.dart';
import '../app_styles.dart';

/// Time period options for data filtering
enum TimePeriod { day, week, month, year }

/// A professional period selector widget for filtering data by time range
/// Part of the Industrial SaaS design system
class PeriodSelector extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final bool showLabels;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimePeriod.values.map((period) {
          final isSelected = period == selectedPeriod;
          return _buildPeriodButton(period, isSelected);
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodButton(TimePeriod period, bool isSelected) {
    return GestureDetector(
      onTap: () => onPeriodChanged(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: showLabels ? AppStyles.paddingM : AppStyles.paddingS,
          vertical: AppStyles.paddingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusS),
        ),
        child: Text(
          showLabels ? _getPeriodLabel(period) : _getPeriodShortLabel(period),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: showLabels ? 14 : 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.day:
        return 'Day';
      case TimePeriod.week:
        return 'Week';
      case TimePeriod.month:
        return 'Month';
      case TimePeriod.year:
        return 'Year';
    }
  }

  String _getPeriodShortLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.day:
        return 'D';
      case TimePeriod.week:
        return 'W';
      case TimePeriod.month:
        return 'M';
      case TimePeriod.year:
        return 'Y';
    }
  }
}

/// Extended period selector with date display
class PeriodSelectorWithDate extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback? onDateRangeTap;

  const PeriodSelectorWithDate({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.startDate,
    this.endDate,
    this.onDateRangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PeriodSelector(
          selectedPeriod: selectedPeriod,
          onPeriodChanged: onPeriodChanged,
        ),
        if (startDate != null || endDate != null) ...[
          const SizedBox(height: AppStyles.paddingS),
          GestureDetector(
            onTap: onDateRangeTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDateRange(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (onDateRangeTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateRange() {
    if (startDate == null && endDate == null) return '';
    
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();
    
    final startStr = '${start.day}/${start.month}/${start.year}';
    final endStr = '${end.day}/${end.month}/${end.year}';
    
    if (startStr == endStr) return startStr;
    return '$startStr - $endStr';
  }
}
