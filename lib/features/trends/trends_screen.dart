import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../core/widgets/period_selector.dart';

class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.week;
  String _selectedParameter = 'pH';

  // Sample data for different periods
  final Map<TimePeriod, List<FlSpot>> _healthData = {
    TimePeriod.day: [
      const FlSpot(0, 85), const FlSpot(4, 82), const FlSpot(8, 88),
      const FlSpot(12, 75), const FlSpot(16, 78), const FlSpot(20, 80), const FlSpot(24, 82),
    ],
    TimePeriod.week: [
      const FlSpot(0, 80), const FlSpot(1, 78), const FlSpot(2, 85),
      const FlSpot(3, 82), const FlSpot(4, 88), const FlSpot(5, 86), const FlSpot(6, 84),
    ],
    TimePeriod.month: [
      const FlSpot(0, 85), const FlSpot(5, 82), const FlSpot(10, 88),
      const FlSpot(15, 75), const FlSpot(20, 78), const FlSpot(25, 80), const FlSpot(30, 82),
    ],
    TimePeriod.year: [
      const FlSpot(0, 78), const FlSpot(1, 80), const FlSpot(2, 82),
      const FlSpot(3, 85), const FlSpot(4, 88), const FlSpot(5, 86),
      const FlSpot(6, 84), const FlSpot(7, 82), const FlSpot(8, 80),
      const FlSpot(9, 83), const FlSpot(10, 85), const FlSpot(11, 87),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Performance Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            PeriodSelector(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (period) {
                setState(() => _selectedPeriod = period);
              },
            ),
            const SizedBox(height: AppStyles.paddingL),

            // Main Chart
            Text(
              'System Health Trend',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingS),
            Text(
              _getPeriodLabel(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildChartContainer(_buildHealthChart()),
            const SizedBox(height: AppStyles.paddingL),

            // Parameter Cards
            Text(
              'Parameters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildParameterGrid(),
            const SizedBox(height: AppStyles.paddingL),

            // Risk Chart
            Text(
              'Risk Analysis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildChartContainer(_buildRiskChart()),
            const SizedBox(height: AppStyles.paddingM),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return 'Last 24 hours';
      case TimePeriod.week:
        return 'Last 7 days';
      case TimePeriod.month:
        return 'Last 30 days';
      case TimePeriod.year:
        return 'Last 12 months';
    }
  }

  Widget _buildParameterGrid() {
    final parameters = [
      {'name': 'pH', 'value': '7.2', 'trend': '+0.1', 'color': AppColors.phColor},
      {'name': 'DO', 'value': '8.5', 'trend': '-0.3', 'color': AppColors.doColor},
      {'name': 'Temp', 'value': '22°C', 'trend': '+1.2', 'color': AppColors.tempColor},
      {'name': 'TDS', 'value': '450', 'trend': '+5', 'color': AppColors.info},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppStyles.paddingS,
        mainAxisSpacing: AppStyles.paddingS,
        childAspectRatio: 1.5,
      ),
      itemCount: parameters.length,
      itemBuilder: (context, index) {
        final param = parameters[index];
        final isSelected = _selectedParameter == param['name'];
        return _buildParameterCard(
          name: param['name'] as String,
          value: param['value'] as String,
          trend: param['trend'] as String,
          color: param['color'] as Color,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildParameterCard({
    required String name,
    required String value,
    required String trend,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedParameter = name),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          border: isSelected ? Border.all(color: color, width: 2) : null,
          boxShadow: isSelected ? null : AppShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend.startsWith('+')
                        ? AppColors.successBg
                        : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12,
                      color: trend.startsWith('+')
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(Widget chart) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: chart,
    );
  }

  Widget _buildHealthChart() {
    final data = _healthData[_selectedPeriod] ?? [];
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: _getTitlesData(),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          _getRiskLineData([
            const FlSpot(0, 20), const FlSpot(2, 25), const FlSpot(4, 15), const FlSpot(6, 22),
          ], AppColors.success),
          _getRiskLineData([
            const FlSpot(0, 40), const FlSpot(2, 45), const FlSpot(4, 55), const FlSpot(6, 50),
          ], AppColors.error),
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
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
    );
  }

  FlTitlesData _getTitlesData() {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          getTitlesWidget: (value, meta) {
            if (value % 20 == 0) {
              return Text(
                '${value.toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            return _getBottomLabel(value);
          },
        ),
      ),
    );
  }

  Widget _getBottomLabel(double value) {
    String label = '';
    switch (_selectedPeriod) {
      case TimePeriod.day:
        if (value % 6 == 0) label = '${value.toInt()}h';
        break;
      case TimePeriod.week:
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (value < days.length) label = days[value.toInt()];
        break;
      case TimePeriod.month:
        if (value % 10 == 0) label = 'D${value.toInt()}';
        break;
      case TimePeriod.year:
        final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
        if (value < months.length) label = months[value.toInt()];
        break;
    }
    return Text(
      label,
      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Scaling Risk', AppColors.success),
        const SizedBox(width: AppStyles.paddingM),
        _legendItem('Corrosion Risk', AppColors.error),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppStyles.borderRadiusL)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppStyles.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Options', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppStyles.paddingM),
            ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Factory'),
              subtitle: const Text('All factories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date Range'),
              subtitle: Text(_getPeriodLabel()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
