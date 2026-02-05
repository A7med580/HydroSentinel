import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_styles.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY & TRENDS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SYSTEM HEALTH TREND (30 DAYS)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppStyles.paddingM),
            _buildChartContainer(_buildHealthChart()),
            const SizedBox(height: AppStyles.paddingL),
            Text('RISK EVOLUTION', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppStyles.paddingM),
            _buildChartContainer(_buildRiskChart()),
            const SizedBox(height: AppStyles.paddingL),
            _buildLegend(),
          ],
        ),
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

  Widget _buildHealthChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 85), FlSpot(5, 82), FlSpot(10, 88),
              FlSpot(15, 75), FlSpot(20, 78), FlSpot(25, 80), FlSpot(30, 82),
            ],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          _getRiskLineData([
            const FlSpot(0, 20), const FlSpot(10, 25), const FlSpot(20, 15), const FlSpot(30, 22),
          ], AppColors.riskLow),
          _getRiskLineData([
            const FlSpot(0, 40), const FlSpot(10, 45), const FlSpot(20, 55), const FlSpot(30, 50),
          ], AppColors.riskHigh),
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

  FlTitlesData _getTitlesData() {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (value % 10 == 0) return Text('D${value.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
            return const SizedBox();
          },
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
