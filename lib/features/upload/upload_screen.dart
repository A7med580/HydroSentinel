import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_styles.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isDragging = false;
  bool _isUploading = false;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Upload Excel File'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Zone
            _buildUploadZone(),
            const SizedBox(height: AppStyles.paddingL),

            // Recent Uploads
            Text(
              'Recent Uploads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingM),
            _buildRecentUploads(),
            const SizedBox(height: AppStyles.paddingL),

            // Excel Format Guidelines
            _buildFormatGuidelines(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(AppStyles.paddingXL),
        decoration: BoxDecoration(
          color: _isDragging ? AppColors.infoBg : AppColors.card,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusL),
          border: Border.all(
            color: _isDragging ? AppColors.info : AppColors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppStyles.paddingM),
            Text(
              'Drag and drop your file here or click to browse',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyles.paddingL),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(_isUploading ? 'Uploading...' : 'Choose File'),
            ),
            const SizedBox(height: AppStyles.paddingM),
            Text(
              'Supported formats: .xlsx, .xls • Max size: 10MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: AppStyles.paddingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppStyles.paddingM,
                  vertical: AppStyles.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppStyles.borderRadiusS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _selectedFileName!,
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentUploads() {
    final uploads = [
      {'name': 'water_quality_jan_2026.xlsx', 'date': '2 hours ago', 'records': '1,250'},
      {'name': 'weekly_report_w5.xlsx', 'date': 'Yesterday', 'records': '850'},
      {'name': 'monthly_data_dec.xlsx', 'date': '2 days ago', 'records': '3,200'},
    ];

    return Column(
      children: uploads.map((upload) => _buildUploadItem(upload)).toList(),
    );
  }

  Widget _buildUploadItem(Map<String, String> upload) {
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
                  upload['name']!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${upload['date']} • ${upload['records']} records',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  Widget _buildFormatGuidelines() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingL),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: AppStyles.paddingS),
              Text(
                'Excel File Format Guidelines',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppStyles.paddingM),
          _buildGuidelineItem(
            icon: Icons.table_chart_outlined,
            text: 'Include column headers: Date, Time, Parameter, Value, Unit',
          ),
          const SizedBox(height: AppStyles.paddingS),
          _buildGuidelineItem(
            icon: Icons.calendar_today_outlined,
            text: 'Use ISO date format (YYYY-MM-DD)',
          ),
          const SizedBox(height: AppStyles.paddingS),
          _buildGuidelineItem(
            icon: Icons.numbers_outlined,
            text: 'Ensure numerical values are properly formatted',
          ),
          const SizedBox(height: AppStyles.paddingM),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Download template
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template download started...')),
              );
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppStyles.paddingS),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() => _isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFileName = result.files.first.name);
        
        // Simulate processing
        await Future.delayed(const Duration(seconds: 1));
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "${result.files.first.name}" uploaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
