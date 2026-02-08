import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/period_selector.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.month;
  String? _selectedFactory;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _showExportOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Grid
            _buildKPIGrid(),
            const SizedBox(height: AppStyles.paddingL),

            // Report Generator Section
            Text(
              'Generate Custom Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildReportGenerator(),
            const SizedBox(height: AppStyles.paddingL),

            // Recent Reports
            Text(
              'Recent Reports',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildRecentReports(),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            title: 'Total Parameters',
            value: '24',
            icon: Icons.analytics_outlined,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: _buildKPICard(
            title: 'Active Alerts',
            value: '3',
            icon: Icons.warning_amber_outlined,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: _buildKPICard(
            title: 'Compliance',
            value: '94%',
            icon: Icons.check_circle_outlined,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppStyles.paddingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportGenerator() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingL),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Factory Selector
          DropdownButtonFormField<String>(
            value: _selectedFactory,
            decoration: const InputDecoration(
              labelText: 'Select Factory',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Factories')),
              DropdownMenuItem(value: 'factory1', child: Text('North Bay Processing')),
              DropdownMenuItem(value: 'factory2', child: Text('Central Water Treatment')),
            ],
            onChanged: (value) => setState(() => _selectedFactory = value),
          ),
          const SizedBox(height: AppStyles.paddingM),

          // Period Selector
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppStyles.paddingS),
          PeriodSelector(
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: (period) => setState(() => _selectedPeriod = period),
          ),
          const SizedBox(height: AppStyles.paddingL),

          // Generate Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : () => _generateReport('csv'),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(width: AppStyles.paddingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : () => _generateReport('pdf'),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    final reports = [
      {'name': 'water_quality_jan_2026.xlsx', 'date': '2 hours ago', 'records': '1,250'},
      {'name': 'weekly_report_w5.xlsx', 'date': 'Yesterday', 'records': '850'},
      {'name': 'monthly_data_dec.xlsx', 'date': '2 days ago', 'records': '3,200'},
    ];

    return Column(
      children: reports.map((report) => _buildReportItem(report)).toList(),
    );
  }

  Widget _buildReportItem(Map<String, String> report) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingS),
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(AppStyles.borderRadiusS),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.success),
          ),
          const SizedBox(width: AppStyles.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['name']!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${report['date']} • ${report['records']} records',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
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
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('pdf');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(String format) async {
    setState(() => _isGenerating = true);
    
    // Simulate report generation
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    setState(() => _isGenerating = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report generated successfully as $format'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
