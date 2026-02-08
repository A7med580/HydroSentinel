import 'package:excel/excel.dart';
import '../../../features/factories/domain/measurement_v2.dart';
import 'base_parser.dart';

class MonthlyParser with ChemicalParserMixin implements TemplateParser {
  @override
  PeriodType get type => PeriodType.monthly;

  @override
  bool canParse(Sheet sheet) {
    if (sheet.maxRows == 0) return false;
    // Look for "Month" in Col A and "Year" in Col B
    for (var i = 0; i < min(5, sheet.maxRows); i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue; // Guard against empty rows
      if (row.length < 2) continue; // Ensure there are at least two columns
      
      final colA = row[0]?.value?.toString().toLowerCase().trim();
      final colB = row[1]?.value?.toString().toLowerCase().trim();
      
      if (colA == 'month' && colB == 'year') {
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
      if (row.length >= 2) {
        final colA = row[0]?.value?.toString().toLowerCase().trim();
        final colB = row[1]?.value?.toString().toLowerCase().trim();
        if (colA == 'month' && colB == 'year') {
          headerRowIndex = i;
          break;
        }
      }
    }

    if (headerRowIndex == -1) return [];

    // 2. Parse Rows
    for (var i = headerRowIndex + 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.length < 2) continue;

      final monthVal = row[0]?.value;
      final yearVal = row[1]?.value;

      if (monthVal == null || yearVal == null) continue;

      int? month;
      int? year;

      // Parse Month (could be number 1-12 or name "Jan", "February")
      if (monthVal is int || monthVal is double) {
        month = (monthVal as num).toInt();
      } else if (monthVal is String) {
        month = _parseMonthString(monthVal.toString());
      }

      // Parse Year
      if (yearVal is int || yearVal is double) {
        year = (yearVal as num).toInt();
      } else if (yearVal is String) {
        year = int.tryParse(yearVal.toString());
      }

      if (month == null || year == null) continue;

      // Create Date Range (Start of Month -> End of Month)
      final startDate = DateTime.utc(year, month, 1);
      // Logic for end of month: First day of next month minus 1 day
      final nextMonth = month == 12 ? DateTime.utc(year + 1, 1, 1) : DateTime.utc(year, month + 1, 1);
      final endDate = nextMonth.subtract(const Duration(days: 1));

      // Parse Chemical Data (Mixin)
      final data = parseChemicalData(row);

      if (data.isNotEmpty) {
        measurements.add(MeasurementV2(
          factoryId: factoryId,
          periodType: PeriodType.monthly,
          startDate: startDate,
          endDate: endDate,
          data: data,
          uploadId: uploadId,
        ));
      }
    }

    return measurements;
  }

  int? _parseMonthString(String input) {
    final lower = input.toLowerCase().trim();
    if (int.tryParse(lower) != null) return int.parse(lower);

    // Simple map for month names
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };

    for (var key in months.keys) {
      if (lower.startsWith(key)) return months[key];
    }
    return null;
  }

  int min(int a, int b) => a < b ? a : b;
}
