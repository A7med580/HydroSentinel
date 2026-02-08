import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import '../../../core/widgets/factory_card.dart';
import '../domain/factory_entity.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Text('Syncing factories...'),
          ],
        ),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        ),
      ),
    );
    
    try {
      await ref.read(factoryRepositoryProvider).syncWithDrive();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 12),
              Text('Sync complete'),
            ],
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(child: Text('Sync failed: $e')),
            ],
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          ),
        ),
      );
    }
  }
}
