import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_styles.dart';
import '../../core/widgets/period_selector.dart';
import '../../services/aggregated_data_provider.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final asyncData = ref.watch(aggregatedDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY & TRENDS')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          if (data == null || data.dailyCalculations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No trend data available', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  SizedBox(height: 8),
                  Text('Upload data to see trends', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SYSTEM HEALTH TREND', style: Theme.of(context).textTheme.titleLarge),
                    PeriodSelector(
                      selectedPeriod: selectedPeriod,
                      onPeriodChanged: (period) {
                        ref.read(selectedPeriodProvider.notifier).setPeriod(period);
                      },
                      showLabels: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.dailyCalculations.length} data points • ${selectedPeriod.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppStyles.paddingM),
                _buildChartContainer(_buildHealthChart(data)),

                const SizedBox(height: AppStyles.paddingL),
                Text('RISK EVOLUTION', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildChartContainer(_buildRiskChart(data)),

                const SizedBox(height: AppStyles.paddingL),
                _buildLegend(),
                const SizedBox(height: AppStyles.paddingL),

                // Parameter summary cards
                Text('PARAMETER AVERAGES', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildParameterSummary(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartContainer(Widget chart) {
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: chart,
    );
  }

  Widget _buildHealthChart(AggregatedData data) {
    final dailyCalcs = data.dailyCalculations;
    final healthSpots = <FlSpot>[];

    for (int i = 0; i < dailyCalcs.length; i++) {
      healthSpots.add(FlSpot(i.toDouble(), dailyCalcs[i].health.overallScore.clamp(0, 100)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(dailyCalcs),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: healthSpots,
            isCurved: true,
            color: Colors.black, // Health = black per spec
            barWidth: 3,
            dotData: FlDotData(show: dailyCalcs.length <= 31),
            belowBarData: BarAreaData(show: true, color: Colors.black.withValues(alpha: 0.05)),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart(AggregatedData data) {
    final dailyCalcs = data.dailyCalculations;
    final scalingSpots = <FlSpot>[];
    final corrosionSpots = <FlSpot>[];

    for (int i = 0; i < dailyCalcs.length; i++) {
      scalingSpots.add(FlSpot(i.toDouble(), dailyCalcs[i].risk.scalingScore.clamp(0, 100)));
      corrosionSpots.add(FlSpot(i.toDouble(), dailyCalcs[i].risk.corrosionScore.clamp(0, 100)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(dailyCalcs),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          _getRiskLineData(scalingSpots, Colors.green),  // Scaling = green per spec
          _getRiskLineData(corrosionSpots, Colors.yellow.shade700), // Corrosion = yellow per spec
        ],
      ),
    );
  }

  LineChartBarData _getRiskLineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: spots.length <= 31),
    );
  }

  FlTitlesData _getTitlesData(List<DailyCalculation> dailyCalcs) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= dailyCalcs.length) return const SizedBox();
            
            // Show every Nth label to avoid crowding
            final interval = dailyCalcs.length <= 7 ? 1 : 
                            dailyCalcs.length <= 31 ? 5 : 
                            dailyCalcs.length <= 365 ? 30 : 60;
            if (index % interval != 0 && index != dailyCalcs.length - 1) return const SizedBox();
            
            final date = dailyCalcs[index].date;
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${date.day}/${date.month}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Health', Colors.black),
        const SizedBox(width: 16),
        _legendItem('Scaling', Colors.green),
        const SizedBox(width: 16),
        _legendItem('Corrosion', Colors.yellow.shade700),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  /// Shows averaged parameter values as a grid of cards
  Widget _buildParameterSummary(AggregatedData data) {
    final ct = data.ctData;
    final params = [
      _ParamItem('pH', ct.ph.value, ct.ph.unit, ct.ph.optimalMin ?? 0, ct.ph.optimalMax ?? 0),
      _ParamItem('Alkalinity', ct.alkalinity.value, ct.alkalinity.unit, ct.alkalinity.optimalMin ?? 0, ct.alkalinity.optimalMax ?? 0),
      _ParamItem('Conductivity', ct.conductivity.value, ct.conductivity.unit, ct.conductivity.optimalMin ?? 0, ct.conductivity.optimalMax ?? 0),
      _ParamItem('Hardness', ct.totalHardness.value, ct.totalHardness.unit, ct.totalHardness.optimalMin ?? 0, ct.totalHardness.optimalMax ?? 0),
      _ParamItem('Chloride', ct.chloride.value, ct.chloride.unit, ct.chloride.optimalMin ?? 0, ct.chloride.optimalMax ?? 0),
      _ParamItem('Zinc', ct.zinc.value, ct.zinc.unit, ct.zinc.optimalMin ?? 0, ct.zinc.optimalMax ?? 0),
      _ParamItem('Iron', ct.iron.value, ct.iron.unit, ct.iron.optimalMin ?? 0, ct.iron.optimalMax ?? 0),
      _ParamItem('Phosphates', ct.phosphates.value, ct.phosphates.unit, ct.phosphates.optimalMin ?? 0, ct.phosphates.optimalMax ?? 0),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: params.length,
      itemBuilder: (context, index) {
        final p = params[index];
        final inRange = p.value >= p.min && p.value <= p.max;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: inRange ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.name, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    p.value.toStringAsFixed(1),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: inRange ? Colors.green : Colors.redAccent),
                  ),
                  const SizedBox(width: 4),
                  Text(p.unit, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              Text('Range: ${p.min}-${p.max}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ],
          ),
        );
      },
    );
  }
}

class _ParamItem {
  final String name;
  final double value;
  final String unit;
  final double min;
  final double max;
  const _ParamItem(this.name, this.value, this.unit, this.min, this.max);
}
