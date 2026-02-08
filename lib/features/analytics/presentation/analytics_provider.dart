import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/analytics_service.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

// Services
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(Supabase.instance.client);
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepositoryImpl(ref.watch(analyticsServiceProvider));
});

// State classes
class AnalyticsState {
  final TimePeriod period;
  final DateRange range;
  
  AnalyticsState({required this.period, required this.range});
  
  AnalyticsState copyWith({TimePeriod? period, DateRange? range}) {
    return AnalyticsState(
      period: period ?? this.period,
      range: range ?? this.range,
    );
  }
}

// Notifier for Period/Range selection (Riverpod 2.x/3.x compatible)
class AnalyticsFilterNotifier extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    return AnalyticsState(
      period: TimePeriod.month,
      range: DateRange(startOfMonth, endOfMonth),
    );
  }

  void updatePeriod(TimePeriod period) {
    state = state.copyWith(period: period);
  }

  void updateRange(DateRange range) {
    state = state.copyWith(range: range);
  }
}

final analyticsFilterProvider = NotifierProvider<AnalyticsFilterNotifier, AnalyticsState>(
  AnalyticsFilterNotifier.new,
);

// Main Data Provider
final analyticsDataProvider = FutureProvider.family<AnalyticsData, String>((ref, factoryId) async {
  final filter = ref.watch(analyticsFilterProvider);
  final repo = ref.watch(analyticsRepositoryProvider);
  
  final result = await repo.getAnalytics(
    factoryId: factoryId,
    period: filter.period,
    range: filter.range,
  );
  
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});
