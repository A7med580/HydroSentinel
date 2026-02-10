import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import '../../../core/widgets/factory_card.dart';
import '../domain/factory_entity.dart';
import '../domain/factory_repository.dart'; // Import SyncSummary
import 'factory_providers.dart';
import 'factory_home_screen.dart';

class FactoriesScreen extends ConsumerWidget {
  const FactoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factoriesAsync = ref.watch(factoriesStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              title: const Text('My Factories'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync with Storage',
                  onPressed: () => _handleSync(context, ref),
                ),
              ],
            ),
            
            // Content
            factoriesAsync.when(
              data: (factories) {
                if (factories.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(context, ref),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(AppStyles.paddingM),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final factory = factories[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppStyles.paddingM),
                          child: Dismissible(
                            key: Key(factory.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: AppStyles.paddingL),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(AppStyles.borderRadius),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Factory?'),
                                  content: const Text(
                                    'Are you sure you want to delete this factory from the app?\n\n'
                                    'Note: If the factory folder still exists in Google Drive, it will reappear during the next sync.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              // Optimistic update handled by Stream? 
                              // No, stream will update when DB updates.
                              // But we need to call delete.
                              
                              final result = await ref.read(factoryRepositoryProvider).deleteFactory(factory.id);
                              
                              if (context.mounted) {
                                result.fold(
                                  (failure) {
                                    // Verify if we should undo? 
                                    // If deletion failed, the item is theoretically still there but dismissed from UI?
                                    // StreamBuilder should handle state, but Dismissible removes it from tree locally?
                                    // Actually, if stream updates, it rebuilds.
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: ${failure.message}')),
                                    );
                                  },
                                  (_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Factory deleted')),
                                    );
                                  },
                                );
                              }
                            },
                            child: FactoryCard(
                              name: factory.name,
                              status: _getStatusString(factory.status),
                              lastSyncAt: factory.lastSyncAt,
                              healthScore: factory.healthScore,
                              alertCount: factory.alertCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FactoryHomeScreen(factory: factory),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: factories.length,
                    ),
                  ),
                );
              },
              error: (error, stack) => SliverFillRemaining(
                child: _buildErrorState(error.toString()),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleSync(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.cloud_sync),
        label: const Text('Sync'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppStyles.borderRadiusL),
              ),
              child: const Icon(
                Icons.factory_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppStyles.paddingL),
            Text(
              'No Factories Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingS),
            Text(
              'Sync with your storage to load factories and their monitoring data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppStyles.paddingL),
            ElevatedButton.icon(
              onPressed: () => _handleSync(context, ref),
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppStyles.paddingM),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppStyles.paddingS),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusString(FactoryStatus status) {
    switch (status) {
      case FactoryStatus.good:
        return 'Online';
      case FactoryStatus.warning:
        return 'Warning';
      case FactoryStatus.critical:
        return 'Critical';
    }
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Syncing factories...'),
          ],
        ),
        duration: const Duration(days: 1), // Indefinite until dismissed
      ),
    );
    
    final result = await ref.read(factoryRepositoryProvider).syncWithDrive();
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    result.fold(
      (failure) {
        _showErrorDialog(context, 'Sync Failed', failure.message);
      },
      (summary) {
        _showSyncResultDialog(context, summary);
      },
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: AppColors.error)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSyncResultDialog(BuildContext context, SyncSummary summary) {
    if (summary.processedFiles == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files found to sync.')),
      );
      return;
    }

    final hasErrors = summary.failureCount > 0;
    final hasMissingData = summary.missingDataFiles.isNotEmpty;
    final isPerfect = !hasErrors && !hasMissingData;

    if (isPerfect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${summary.successCount} files successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasErrors ? Icons.warning_amber : Icons.info_outline,
              color: hasErrors ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text('Sync Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Processed: ${summary.processedFiles}'),
              Text('Success: ${summary.successCount}', style: const TextStyle(color: AppColors.success)),
              if (hasErrors)
                Text('Failed: ${summary.failureCount}', style: const TextStyle(color: AppColors.error)),
              
              if (hasMissingData) ...[
                const SizedBox(height: 16),
                const Text('Missing Data Detected:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...summary.missingDataFiles.entries.map((e) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${e.key}: Missing ${e.value.join(", ")}', style: const TextStyle(fontSize: 12)),
                  )
                ).take(5), // Limit to 5 to avoid overflow
                if (summary.missingDataFiles.length > 5)
                  Text('+ ${summary.missingDataFiles.length - 5} more files...'),
              ],

              if (hasErrors && summary.errorMessages.isNotEmpty) ...[
                 const SizedBox(height: 16),
                 const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 ...summary.errorMessages.map((e) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $e', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    )
                 ).take(5),
                 if (summary.errorMessages.length > 5)
                    Text('+ ${summary.errorMessages.length - 5} more errors...'),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
