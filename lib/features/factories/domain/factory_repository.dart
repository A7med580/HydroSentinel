import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import 'factory_entity.dart';
import 'report_entity.dart';


class SyncSummary {
  final int processedFiles;
  final int successCount;
  final int failureCount;
  final List<String> errorMessages;
  final Map<String, List<String>> missingDataFiles; // FileName -> MissingParams

  SyncSummary({
    this.processedFiles = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.errorMessages = const [],
    this.missingDataFiles = const {},
  });

  SyncSummary operator +(SyncSummary other) {
    return SyncSummary(
      processedFiles: processedFiles + other.processedFiles,
      successCount: successCount + other.successCount,
      failureCount: failureCount + other.failureCount,
      errorMessages: [...errorMessages, ...other.errorMessages],
      missingDataFiles: {...missingDataFiles, ...other.missingDataFiles},
    );
  }
}

abstract class FactoryRepository {
  Stream<List<FactoryEntity>> watchFactories();
  Future<Either<Failure, SyncSummary>> syncWithDrive(); // Updated return type
  Future<Either<Failure, List<ReportEntity>>> getReportsForFactory(String factoryId);
  Future<Either<Failure, void>> deleteFactory(String factoryId);
  Future<Either<Failure, void>> deleteReport(String reportId, String filePath); // New method
}

