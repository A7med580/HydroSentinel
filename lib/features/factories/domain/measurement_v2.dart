import 'package:excel/excel.dart';

enum PeriodType { daily, weekly, monthly, yearly }

/// Core data model for V2 architecture
/// Represents a single time-series data point with strict typing
class MeasurementV2 {
  final String? id;
  final String factoryId;
  final PeriodType periodType;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> data; // Chemical values
  final Map<String, dynamic> indices; // Calculated indices (LSI, RSI...)
  final String? uploadId;

  MeasurementV2({
    this.id,
    required this.factoryId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.data,
    this.indices = const {},
    this.uploadId,
  });

  Map<String, dynamic> toJson() {
    return {
      'factory_id': factoryId,
      'period_type': periodType.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'data': data,
      'indices': indices,
      'upload_id': uploadId,
    };
  }
}

/// Abstract interface for all template parsers
abstract class TemplateParser {
  /// Unique identifier for the template type (e.g., 'DAILY', 'WEEKLY')
  PeriodType get type;

  /// Determines if this parser can handle the provided Excel sheet
  bool canParse(Sheet sheet);

  /// Parsers the sheet into a list of standardized measurements
  List<MeasurementV2> parse(Sheet sheet, String factoryId, String? uploadId);
}
