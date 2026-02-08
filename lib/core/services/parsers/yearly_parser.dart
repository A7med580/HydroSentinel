import 'package:excel/excel.dart';
import '../../../features/factories/domain/measurement_v2.dart';
import 'base_parser.dart';

class YearlyParser with ChemicalParserMixin implements TemplateParser {
  @override
  PeriodType get type => PeriodType.yearly;

  @override
  bool canParse(Sheet sheet) {
    if (sheet.maxRows == 0) return false;
    // Look for "Year" in Col A
    for (var i = 0; i < min(5, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;
      
      final colA = row[0]?.value?.toString().toLowerCase().trim();
      if (colA == 'year') {
        return true;
      }
    }
    return false;
  }

  @override
  List<MeasurementV2> parse(Sheet sheet, String factoryId, String? uploadId) {
    final List<MeasurementV2> measurements = [];
    int headerRowIndex = -1;

    // 1. Find Header
    for (var i = 0; i < min(5, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isNotEmpty && row[0]?.value?.toString().toLowerCase().trim() == 'year') {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex == -1) return [];

    // 2. Parse Rows
    for (var i = headerRowIndex + 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final yearVal = row[0]?.value;
      if (yearVal == null) continue;

      int? year;
      if (yearVal is int || yearVal is double) {
        year = (yearVal as num).toInt();
      } else if (yearVal is String) {
        year = int.tryParse(yearVal.toString());
      }

      if (year == null) continue;

      final startDate = DateTime.utc(year, 1, 1);
      final endDate = DateTime.utc(year, 12, 31);

      // Parse Chemical Data
      final data = parseChemicalData(row);

      if (data.isNotEmpty) {
        measurements.add(MeasurementV2(
          factoryId: factoryId,
          periodType: PeriodType.yearly,
          startDate: startDate,
          endDate: endDate,
          data: data,
          uploadId: uploadId,
        ));
      }
    }

    return measurements;
  }

  int min(int a, int b) => a < b ? a : b;
}
