import 'package:excel/excel.dart';
import '../../../features/factories/domain/measurement_v2.dart';
import 'base_parser.dart';

class WeeklyParser with ChemicalParserMixin implements TemplateParser {
  @override
  PeriodType get type => PeriodType.weekly;

  @override
  bool canParse(Sheet sheet) {
    // Look for "Week Start" in Column A
    for (var i = 0; i < min(5, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;
      
      final firstCell = row[0]?.value?.toString().toLowerCase().trim();
      if (firstCell != null && firstCell.contains('week') && firstCell.contains('start')) {
        return true;
      }
    }
    return false;
  }

  @override
  List<MeasurementV2> parse(Sheet sheet, String factoryId, String? uploadId) {
    final List<MeasurementV2> measurements = [];
    int headerRowIndex = -1;

    // 1. Find Header Row
    for (var i = 0; i < min(5, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isNotEmpty) {
        final val = row[0]?.value?.toString().toLowerCase().trim();
        if (val != null && val.contains('week') && val.contains('start')) {
          headerRowIndex = i;
          break;
        }
      }
    }

    if (headerRowIndex == -1) return [];

    // 2. Parse Rows
    for (var i = headerRowIndex + 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      // Parse Week Start (Column A)
      final startCell = row[0];
      // Parse Week End (Column B)
      final endCell = row[1];

      if (startCell == null || startCell.value == null) continue;

      DateTime? startDate;
      final startCellValue = startCell.value;
      if (startCellValue is DateCellValue) {
        startDate = startCellValue.asDateTimeLocal();
      } else if (startCellValue is TextCellValue) {
        startDate = DateTime.tryParse(startCellValue.value.toString());
      }

      DateTime? endDate;
      if (endCell != null && endCell.value != null) {
        final endCellValue = endCell.value;
        if (endCellValue is DateCellValue) {
          endDate = endCellValue.asDateTimeLocal();
        } else if (endCellValue is TextCellValue) {
          endDate = DateTime.tryParse(endCellValue.value.toString());
        }
      }

      // If no end date, assume 6 days later (Standard week)
      if (startDate != null && endDate == null) {
        endDate = startDate.add(const Duration(days: 6));
      }

      if (startDate == null) continue;

      // Parse Chemical Data (using Mixin)
      final data = parseChemicalData(row);

      if (data.isNotEmpty) {
        measurements.add(MeasurementV2(
          factoryId: factoryId,
          periodType: PeriodType.weekly,
          startDate: DateTime.utc(startDate.year, startDate.month, startDate.day),
          endDate: DateTime.utc(endDate!.year, endDate.month, endDate.day),
          data: data,
          uploadId: uploadId,
        ));
      }
    }

    return measurements;
  }

  int min(int a, int b) => a < b ? a : b;
}
