import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_styles.dart';
import '../../core/widgets/status_badge.dart';
import '../factories/presentation/factory_providers.dart';
import '../factories/domain/factory_entity.dart';
import '../factories/presentation/factory_home_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factoriesAsync = ref.watch(factoriesStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Facilities'),
            factoriesAsync.when(
              data: (factories) => Text(
                '${factories.length} monitoring locations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search facilities...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Factory List
          Expanded(
            child: factoriesAsync.when(
              data: (factories) {
                final filteredFactories = factories
                    .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();

                if (filteredFactories.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppStyles.paddingM),
                  itemCount: filteredFactories.length,
                  itemBuilder: (context, index) {
                    return _buildFactoryCard(filteredFactories[index]);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppStyles.paddingM),
                    Text('Error loading facilities', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppStyles.paddingS),
                    Text(error.toString(), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _syncFactories(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFactoryCard(FactoryEntity factory) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FactoryHomeScreen(factory: factory),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppStyles.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factory.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Location', // Could add location field to FactoryEntity
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: _getStatusString(factory.status),
                      type: _getStatusType(factory.status),
                    ),
                    const SizedBox(width: AppStyles.paddingS),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: AppStyles.paddingS),
                
                // Updated time
                Row(
                  children: [
                    if (factory.lastSyncAt != null) ...[
                      Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Updated ${_formatTimeAgo(factory.lastSyncAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppStyles.paddingM),
                
                // KPI Row
                Row(
                  children: [
                    _buildKPIItem('pH', '7.2', AppColors.phColor),
                    const SizedBox(width: AppStyles.paddingM),
                    _buildKPIItem('DO', '8.5 mg/L', AppColors.doColor),
                    const SizedBox(width: AppStyles.paddingM),
                    _buildKPIItem('Temp', '22°C', AppColors.tempColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPIItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppStyles.paddingS,
          vertical: AppStyles.paddingS,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusS),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                boxShadow: AppShadows.card,
              ),
              child: const Icon(
                Icons.factory_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppStyles.paddingL),
            Text(
              'No Facilities Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppStyles.paddingS),
            Text(
              'Add your first facility to start monitoring water quality.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppStyles.paddingL),
            ElevatedButton.icon(
              onPressed: _syncFactories,
              icon: const Icon(Icons.add),
              label: const Text('Add Facility'),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusString(FactoryStatus status) {
    switch (status) {
      case FactoryStatus.good:
        return 'Operational';
      case FactoryStatus.warning:
        return 'Warning';
      case FactoryStatus.critical:
        return 'Critical';
    }
  }

  StatusType _getStatusType(FactoryStatus status) {
    switch (status) {
      case FactoryStatus.good:
        return StatusType.success;
      case FactoryStatus.warning:
        return StatusType.warning;
      case FactoryStatus.critical:
        return StatusType.critical;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> _syncFactories() async {
    try {
      await ref.read(factoryRepositoryProvider).syncWithDrive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync complete'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
