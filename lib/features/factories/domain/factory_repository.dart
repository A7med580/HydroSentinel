import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import 'factory_entity.dart';
import 'report_entity.dart';

abstract class FactoryRepository {
  Stream<List<FactoryEntity>> watchFactories();
  Future<Either<Failure, void>> syncWithDrive();
  Future<Either<Failure, List<ReportEntity>>> getReportsForFactory(String factoryId);
}
