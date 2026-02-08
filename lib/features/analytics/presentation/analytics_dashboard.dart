import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import 'analytics_provider.dart';
import '../domain/analytics_models.dart';
import 'widgets/analytics_card.dart';

class AnalyticsDashboard extends ConsumerWidget {
  final String factoryId;

  const AnalyticsDashboard({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsDataProvider(factoryId));
    final currentFilter = ref.watch(analyticsFilterProvider);

    return Column(
      children: [
        // 1. Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Period Selector
              DropdownButton<TimePeriod>(
                value: currentFilter.period,
                items: TimePeriod.values.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name.toUpperCase()),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(analyticsFilterProvider.notifier).updatePeriod(val);
                  }
                },
              ),
              const SizedBox(width: 16),
              // Date Range Display
              Expanded(
                child: Text(
                  '${currentFilter.range.start.toLocal().toString().split(' ')[0]} - ${currentFilter.range.end.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: DateTimeRange(
                      start: currentFilter.range.start,
                      end: currentFilter.range.end,
                    ),
                  );
                  if (range != null) {
                    ref.read(analyticsFilterProvider.notifier).updateRange(DateRange(range.start, range.end));
                  }
                },
              ),
            ],
          ),
        ),

        // 2. Metrics Grid
        Expanded(
          child: analyticsAsync.when(
            data: (data) => GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: AnalyticsParameter.values.length,
              itemBuilder: (context, index) {
                final param = AnalyticsParameter.values[index];
                final value = data.metrics[param] ?? 0.0;
                return AnalyticsCard(
                  title: param.label,
                  value: value.toStringAsFixed(2),
                  unit: param.unit,
                  color: _getColorForParam(param, value),
                );
              },
            ),
            error: (e, st) => Center(child: Text('Error: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Color _getColorForParam(AnalyticsParameter param, double value) {
    if (param == AnalyticsParameter.ph) {
      if (value < 6.5 || value > 8.5) return AppColors.riskCritical;
      if (value < 7.0 || value > 8.0) return AppColors.riskMedium;
      return AppColors.riskLow;
    }
    return AppColors.primary;
  }
}
