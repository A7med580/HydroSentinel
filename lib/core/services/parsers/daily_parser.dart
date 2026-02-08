import 'package:excel/excel.dart';
import '../../../features/factories/domain/measurement_v2.dart';
import 'base_parser.dart';

class DailyParser with ChemicalParserMixin implements TemplateParser {
  @override
  PeriodType get type => PeriodType.daily;

  @override
  bool canParse(Sheet sheet) {
    // Check header rows (expanded search range)
    for (var i = 0; i < min(10, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;
      
      // Check multiple columns for the "Date" keyword to handle varied templates
      for (var j = 0; j < min(3, row.length); j++) {
        final cellValue = row[j]?.value?.toString().toLowerCase().trim();
        if (cellValue == 'date') {
          return true;
        }
      }
    }
    return false;
  }

  @override
  List<MeasurementV2> parse(Sheet sheet, String factoryId, String? uploadId) {
    final List<MeasurementV2> measurements = [];
    int headerRowIndex = -1;

    // 1. Find Header Row (expanded search range)
    for (var i = 0; i < min(10, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;
      for (var j = 0; j < min(3, row.length); j++) {
        if (row[j]?.value?.toString().toLowerCase().trim() == 'date') {
          headerRowIndex = i;
          break;
        }
      }
      if (headerRowIndex != -1) break;
    }

    if (headerRowIndex == -1) return [];

    // 2. Parse Rows
    for (var i = headerRowIndex + 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      // Parse Date (Column A)
      final dateCell = row[0];
      if (dateCell == null || dateCell.value == null) continue;

      DateTime? date;
      // Handle different date formats
      final cellValue = dateCell.value;
      if (cellValue is DateCellValue) {
        date = cellValue.asDateTimeLocal();
      } else if (cellValue is TextCellValue) {
        date = DateTime.tryParse(cellValue.value.toString());
      }

      if (date == null) continue;

      // Normalize to midnight UTC for "Date" type
      final normalizedDate = DateTime.utc(date.year, date.month, date.day);

      // Parse Chemical Data (using Mixin)
      final data = parseChemicalData(row);

      if (data.isNotEmpty) {
        measurements.add(MeasurementV2(
          factoryId: factoryId,
          periodType: PeriodType.daily,
          startDate: normalizedDate,
          endDate: normalizedDate, // Daily: Start == End
          data: data,
          uploadId: uploadId,
        ));
      }
    }

    return measurements;
  }
  
  int min(int a, int b) => a < b ? a : b;
}
