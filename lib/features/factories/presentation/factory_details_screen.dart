import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/app_styles.dart';
import '../domain/factory_entity.dart';
import '../domain/report_entity.dart';
import '../data/storage_service.dart';
import 'widgets/simple_delete_dialog.dart';
import 'factory_providers.dart';

class FactoryDetailsScreen extends ConsumerWidget {
  final FactoryEntity factory;

  const FactoryDetailsScreen({super.key, required this.factory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(factoryReportsProvider(factory.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(factory.name.toUpperCase()),
        actions: [
          // Manual Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(syncTriggerProvider.notifier).increment();
            },
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No Analysis Reports Found.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to upload an Excel file.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildReportCard(context, ref, reports[index]);
            },
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      // Upload FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleUploadFile(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _handleUploadFile(BuildContext context, WidgetRef ref) async {
    try {
      // Pick Excel file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file'), backgroundColor: AppColors.riskCritical),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading file...'), duration: Duration(seconds: 1)),
      );

      // Upload to Supabase Storage
      final storageService = ref.read(storageServiceProvider);
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in'), backgroundColor: AppColors.riskCritical),
        );
        return;
      }

      // Use email prefix for folder naming
      final email = user.email ?? 'unknown';
      await storageService.uploadFile(email, factory.name, file.name, file.bytes!);

      // Trigger sync to process the new file
      await ref.read(factoryRepositoryProvider).syncWithDrive();
      ref.read(syncTriggerProvider.notifier).increment();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${file.name} successfully!'),
            backgroundColor: AppColors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.riskCritical),
        );
      }
    }
  }

  Widget _buildReportCard(BuildContext context, WidgetRef ref, ReportEntity report) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppStyles.paddingS),
      child: ExpansionTile(
        title: Text(
          report.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Analyzed: ${_formatDate(report.analyzedAt)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.riskCritical),
          onPressed: () => _handleDeleteReport(context, ref, report.id, report.fileName),
          tooltip: 'Delete Report',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRiskRow('Scaling Risk', report.data['risk_scaling'] ?? 0),
                _buildRiskRow('Corrosion Risk', report.data['risk_corrosion'] ?? 0),
                const SizedBox(height: 8),
                const Text('File Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'File: ${report.fileName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRow(String label, dynamic value) {
    final double safeValue = (value is num) ? value.toDouble() : 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          safeValue.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: safeValue > 50 ? AppColors.riskCritical : AppColors.riskLow,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }
  
  Future<void> _handleDeleteReport(
    BuildContext context,
    WidgetRef ref,
    String reportId,
    String fileName,
  ) async {
    final storageService = StorageService(Supabase.instance.client);
    final email = Supabase.instance.client.auth.currentUser?.email;
    
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Not logged in'),
          backgroundColor: AppColors.riskCritical,
        ),
      );
      return;
    }
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleDeleteDialog(
        reportName: fileName,
        onDelete: () async {
          // Delete from Supabase storage using correct path
          await storageService.deleteFile(email, factory.name, fileName);
        },
      ),
    );
    
    if (result == true && context.mounted) {
      // Refresh the reports list
      ref.read(syncTriggerProvider.notifier).increment();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted successfully'),
          backgroundColor: AppColors.riskLow,
        ),
      );
    }
  }
}
