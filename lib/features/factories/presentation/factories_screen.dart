import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import '../domain/factory_entity.dart';
import 'factory_providers.dart';
import 'factory_details_screen.dart';
import 'factory_home_screen.dart';

class FactoriesScreen extends ConsumerWidget {
  const FactoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factoriesAsync = ref.watch(factoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY FACTORIES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _handleSync(context, ref),
          ),
        ],
      ),
      body: factoriesAsync.when(
        data: (factories) {
          if (factories.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            itemCount: factories.length,
            itemBuilder: (context, index) {
              return _buildFactoryCard(context, factories[index]);
            },
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.factory, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No Factories Found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Tap sync to load from Storage',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryCard(BuildContext context, FactoryEntity factory) {
    Color statusColor;
    switch (factory.status) {
      case FactoryStatus.good: statusColor = AppColors.riskLow; break;
      case FactoryStatus.warning: statusColor = AppColors.riskMedium; break;
      case FactoryStatus.critical: statusColor = AppColors.riskCritical; break;
    }

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppStyles.paddingM),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.business, color: statusColor),
        ),
        title: Text(
          factory.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Last Sync: ${_formatDate(factory.lastSyncAt)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return '${date.day}/${date.month} ${date.hour}:${date.minute}';
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing Factories...')),
    );
    try {
      await ref.read(factoryRepositoryProvider).syncWithDrive();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync Complete')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync Failed: $e')),
      );
    }
  }
}
