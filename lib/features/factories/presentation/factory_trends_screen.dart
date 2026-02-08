import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hydrosentinel/core/app_styles.dart';
import 'factory_providers.dart';
import 'package:hydrosentinel/features/factories/domain/report_entity.dart';

class FactoryTrendsScreen extends ConsumerWidget {
  final String factoryId;

  const FactoryTrendsScreen({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(factoryReportsProvider(factoryId));

    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY & TRENDS')),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (reports) {
          if (reports.isEmpty) {
             return const Center(child: Text('No historical data available.'));
          }
          
          // Sort reports by date ascending for the chart
          final sortedReports = List<ReportEntity>.from(reports)
            ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYSTEM HEALTH TREND', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildChartContainer(_buildHealthChart(sortedReports)),
                const SizedBox(height: AppStyles.paddingL),
                Text('RISK EVOLUTION', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildChartContainer(_buildRiskChart(sortedReports)),
                const SizedBox(height: AppStyles.paddingL),
                _buildLegend(),
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

  Widget _buildHealthChart(List<ReportEntity> reports) {
    // Basic approximate health score trend since we don't save the full score in DB explicitly
    // We will infer it roughly from risks: 100 - avg(risks)
    final spots = reports.asMap().entries.map((entry) {
      final index = entry.key;
      final report = entry.value;
      
      double scaling = (report.data['risk_scaling'] as num?)?.toDouble() ?? 0;
      double corrosion = (report.data['risk_corrosion'] as num?)?.toDouble() ?? 0;
      double fouling = (report.data['risk_fouling'] as num?)?.toDouble() ?? 0;
      
      double avgRisk = (scaling + corrosion + fouling) / 3;
      double score = 100 - avgRisk;
      
      return FlSpot(index.toDouble(), score.clamp(0, 100));
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(reports),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart(List<ReportEntity> reports) {
    final scalingSpots = <FlSpot>[];
    final corrosionSpots = <FlSpot>[];

    reports.asMap().forEach((index, report) {
      double scaling = (report.data['risk_scaling'] as num?)?.toDouble() ?? 0;
      double corrosion = (report.data['risk_corrosion'] as num?)?.toDouble() ?? 0;
      
      scalingSpots.add(FlSpot(index.toDouble(), scaling));
      corrosionSpots.add(FlSpot(index.toDouble(), corrosion));
    });

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(reports),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          _getRiskLineData(scalingSpots, AppColors.riskLow),
          _getRiskLineData(corrosionSpots, AppColors.riskHigh),
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
      dotData: const FlDotData(show: true),
    );
  }

  FlTitlesData _getTitlesData(List<ReportEntity> reports) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < reports.length) {
               // Show rudimentary date label (e.g. Month/Day)
               final date = reports[index].analyzedAt;
               return Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text('${date.day}/${date.month}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
               );
            }
            return const SizedBox();
          },
          interval: 1, // Ensure we check every index
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Health', AppColors.primary),
        const SizedBox(width: 16),
        _legendItem('Scaling', AppColors.riskLow),
        const SizedBox(width: 16),
        _legendItem('Corrosion', AppColors.riskHigh),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
