import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/storage_service.dart';
import '../data/factory_repository_impl.dart';
import '../domain/factory_repository.dart';
import '../domain/factory_entity.dart';
import '../domain/report_entity.dart';

// Service Providers
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(Supabase.instance.client);
});

final factoryRepositoryProvider = Provider<FactoryRepository>((ref) {
  return FactoryRepositoryImpl(
    Supabase.instance.client,
    ref.watch(storageServiceProvider),
  );
});

// Stream of Factories
final factoriesStreamProvider = StreamProvider<List<FactoryEntity>>((ref) {
  return ref.watch(factoryRepositoryProvider).watchFactories();
});

// Trigger to force refresh reports after sync
class SyncTrigger extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}
final syncTriggerProvider = NotifierProvider<SyncTrigger, int>(SyncTrigger.new);

// Future for Factory Reports
final factoryReportsProvider = FutureProvider.family<List<ReportEntity>, String>((ref, factoryId) async {
  // Watch the trigger so we re-fetch when it changes
  ref.watch(syncTriggerProvider);
  
  final result = await ref.watch(factoryRepositoryProvider).getReportsForFactory(factoryId);
  return result.fold((failure) => [], (reports) => reports); 
});

// Sync Action Provider
final syncFactoriesProvider = FutureProvider<void>((ref) async {
  await ref.read(factoryRepositoryProvider).syncWithDrive();
  // Force refresh of all report lists
  ref.read(syncTriggerProvider.notifier).increment();
});
