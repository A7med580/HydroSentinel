import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import '../../../core/services/analytics_service.dart';
import '../domain/analytics_models.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsData>> getAnalytics({
    required String factoryId,
    required TimePeriod period,
    required DateRange range,
  });
}

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsService _service;

  AnalyticsRepositoryImpl(this._service);

  @override
  Future<Either<Failure, AnalyticsData>> getAnalytics({
    required String factoryId,
    required TimePeriod period,
    required DateRange range,
  }) async {
    try {
      // Map domain parameters to service request
      final params = AnalyticsParameter.values.map((p) => p.name).toList();
      
      final results = await _service.getAggregatedMetrics(
        factoryId: factoryId,
        startDate: range.start,
        endDate: range.end,
        parameters: params,
      );
      
      final Map<AnalyticsParameter, double> metrics = {};
      results.forEach((key, value) {
        // Find enum by name (case-insensitive usually, but here strict)
        try {
          final param = AnalyticsParameter.values.firstWhere((e) => e.name == key);
          metrics[param] = value;
        } catch (_) {}
      });
      
      return Right(AnalyticsData(
        metrics: metrics,
        period: period,
        range: range,
      ));
    } catch (e) {
      return Left(ServerFailure('Analytics Error: $e'));
    }
  }
}
