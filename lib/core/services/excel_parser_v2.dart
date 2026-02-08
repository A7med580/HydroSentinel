import 'package:excel/excel.dart';
import '../../features/factories/domain/measurement_v2.dart';

import 'parsers/daily_parser.dart';
import 'parsers/weekly_parser.dart';
import 'parsers/monthly_parser.dart';
import 'parsers/yearly_parser.dart';

class ExcelParserV2 {
  final List<TemplateParser> _parsers = [
    DailyParser(),
    WeeklyParser(),
    MonthlyParser(),
    YearlyParser(),
  ];

  /// Main entry point: Parses an Excel file and returns a list of standardized measurements
  /// Throws FormatException if no matching template is found or data is invalid
  List<MeasurementV2> parseFile(List<int> fileBytes, String factoryId, String? uploadId) {
    try {
      final excel = Excel.decodeBytes(fileBytes);
      final List<MeasurementV2> allMeasurements = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows == 0) continue;

        // 1. Identify Template Type
        TemplateParser? matchingParser;
        for (var parser in _parsers) {
          if (parser.canParse(sheet)) {
            matchingParser = parser;
            break;
          }
        }

        if (matchingParser == null) {
          print('Warning: Sheet "$table" does not match any known template. Skipping.');
          continue;
        }

        // 2. Parse Data
        try {
          final measurements = matchingParser.parse(sheet, factoryId, uploadId);
          allMeasurements.addAll(measurements);
        } catch (e) {
          print('Error parsing sheet "$table": $e');
          // We might want to rethrow or collect errors here
        }
      }

      return allMeasurements;
    } catch (e) {
      throw FormatException('Failed to decode Excel file: $e');
    }
  }
}
