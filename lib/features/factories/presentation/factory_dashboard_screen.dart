import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hydrosentinel/core/app_styles.dart';
import 'package:hydrosentinel/models/assessment_models.dart';
import '../data/upload_service.dart';
import 'factory_state_provider.dart';
import 'factory_providers.dart';

/// "Mirror" of the DashboardScreen but scoped to a single Factory
class FactoryDashboardScreen extends ConsumerWidget {
  final String factoryId;

  const FactoryDashboardScreen({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the scoped state for this factory
    final stateAsync = ref.watch(factoryStateProvider(factoryId));

    return stateAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (state) {
        if (state.health == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'No data available for this factory.\nTap Sync to fetch reports.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('FACTORY DASHBOARD')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSystemStatusHeader(state.health!),
                const SizedBox(height: AppStyles.paddingL),
                Text('PRIMARY RISK FACTORS', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildRiskGrid(state.riskAssessment!),
                const SizedBox(height: AppStyles.paddingL),
                if (state.roAssessment != null) ...[
                  Text('REVERSE OSMOSIS PROTECTION', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppStyles.paddingM),
                  _buildRORisks(state.roAssessment!),
                  const SizedBox(height: AppStyles.paddingL),
                ],
                Text('ACTIVE ALERTS', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppStyles.paddingM),
                _buildAlertPreview(state.recommendations),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _handleFileUpload(context, ref),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload File'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  // --- REUSED WIDGETS (Ideally refactored to common widgets, but copied for isolation as requested) ---
  
  Widget _buildSystemStatusHeader(SystemHealth health) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: health.overallScore / 100,
                  strokeWidth: 10,
                  backgroundColor: AppColors.card,
                  color: _getScoreColor(health.overallScore),
                ),
              ),
              Text(
                health.overallScore.toStringAsFixed(0),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: AppStyles.paddingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SYSTEM HEALTH SCORE', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(
                  health.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(health.overallScore),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${health.keyIssues.length} active issues detected', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGrid(RiskAssessment assessment) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: AppStyles.paddingS,
      mainAxisSpacing: AppStyles.paddingS,
      children: [
        _buildRiskIndicator('SCALING', assessment.scalingScore, assessment.scalingRisk),
        _buildRiskIndicator('CORROSION', assessment.corrosionScore, assessment.corrosionRisk),
        _buildRiskIndicator('FOULING', assessment.foulingScore, assessment.foulingRisk),
      ],
    );
  }

  Widget _buildRiskIndicator(String label, double score, RiskLevel level) {
    Color color = _getRiskColor(level);
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingS),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            level.name.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRORisks(ROProtectionAssessment ro) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildROStat('OXIDATION', ro.oxidationRiskScore, flipped: true),
          _buildROStat('SILICA', ro.silicaScalingRiskScore, flipped: true),
          _buildROStat('MEMBRANE LIFE', ro.membraneLifeIndicator),
        ],
      ),
    );
  }

  Widget _buildROStat(String label, double score, {bool flipped = false}) {
    Color color = flipped ? _getScoreColor(100 - score) : _getScoreColor(score);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '${score.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildAlertPreview(List<Recommendation> recommendations) {
    if (recommendations.isEmpty) {
      return const Card(child: ListTile(title: Text('No active alerts. All parameters within range.')));
    }
    return Column(
      children: recommendations.take(2).map((r) => Card(
        color: AppColors.card,
        child: ListTile(
          leading: Icon(
            r.priority == RecommendationPriority.critical ? Icons.error : Icons.warning,
            color: r.priority == RecommendationPriority.critical ? AppColors.riskCritical : AppColors.riskHigh,
          ),
          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )).toList(),
    );
  }

  Color _getScoreColor(double score) {
    if (score > 80) return AppColors.riskLow;
    if (score > 60) return AppColors.riskMedium;
    if (score > 40) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low: return AppColors.riskLow;
      case RiskLevel.medium: return AppColors.riskMedium;
      case RiskLevel.high: return AppColors.riskHigh;
      case RiskLevel.critical: return AppColors.riskCritical;
    }
    return AppColors.riskCritical;
  }

  Future<void> _handleFileUpload(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get factory to access driveFolderId
      final factoriesAsync = ref.read(factoriesStreamProvider);
      final factory = factoriesAsync.value?.firstWhere((f) => f.id == factoryId);
      
      if (factory == null) {
        throw Exception('Factory not found');
      }

      // Create upload service
      final uploadService = UploadService(Supabase.instance.client);
      
      // Pick and upload file
      final fileName = await uploadService.pickAndUploadFile(factory.driveFolderId);
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      if (fileName == null) {
        // User canceled
        return;
      }

      // Show uploading message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded! Syncing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Trigger full sync to process the new file
      print('DEBUG UPLOAD: Starting sync after upload...');
      final syncResult = await ref.read(factoryRepositoryProvider).syncWithDrive();
      print('DEBUG UPLOAD: Sync completed. Result: $syncResult');
      
      // Refresh the factory reports
      print('DEBUG UPLOAD: Incrementing sync trigger...');
      ref.read(syncTriggerProvider.notifier).increment();
      print('DEBUG UPLOAD: Sync trigger incremented');
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File processed successfully: $fileName'),
            backgroundColor: AppColors.riskLow,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: AppColors.riskCritical,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
