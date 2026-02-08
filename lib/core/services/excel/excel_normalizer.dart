import 'package:excel/excel.dart';
import 'schema_definition.dart';

/// Responsible for finding the data table within a chaotic Excel sheet.
class ExcelNormalizer {
  
  /// Scans the sheet to find the most likely header row and extracts data.
  /// Returns a list of maps where each map represents a row with canonical keys.
  static List<Map<String, dynamic>> normalize(Sheet sheet) {
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    int bestHeaderRowIndex = -1;
    int maxMatches = 0;

    // 1. Identify Header Row (Scan top 20 rows)
    int limit = rows.length < 20 ? rows.length : 20;
    for (int i = 0; i < limit; i++) {
        int matches = _countSchemaMatches(rows[i]);
        if (matches > maxMatches) {
          maxMatches = matches;
          bestHeaderRowIndex = i;
        }
    }

    if (bestHeaderRowIndex == -1 || maxMatches < 3) {
      // If we can't find at least 3 recognizable columns, this might not be the right sheet
      // or the format is wildly different.
      // Fallback: Try to pivot? For now, return empty or throw.
      print('Warning: Could not identify a valid header row in sheet ${sheet.sheetName}');
      return [];
    }

    // 2. Map Column Indices to Canonical Keys
    final headerRow = rows[bestHeaderRowIndex];
    final columnMapping = <int, String>{};

    for (int i = 0; i < headerRow.length; i++) {
      final cellValue = headerRow[i]?.value?.toString() ?? '';
      final canonical = ExcelSchema.match(cellValue);
      if (canonical != null) {
        columnMapping[i] = canonical;
      }
    }

    // 3. Extract Data from subsequent rows
    final result = <Map<String, dynamic>>[];
    
    // Start reading from the row AFTER the header
    for (int i = bestHeaderRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final rowData = <String, dynamic>{};
      bool hasData = false;

      for (var entry in columnMapping.entries) {
        final colIndex = entry.key;
        final key = entry.value;

        if (colIndex < row.length) {
          final cell = row[colIndex];
          final value = _parseValue(cell?.value);
          if (value != null) {
             rowData[key] = value;
             hasData = true;
          }
        }
      }

      // Also try to find a date if it wasn't a column (common in "Report Date: X" metadata cells)
      if (!rowData.containsKey(ExcelSchema.date)) {
         final metadataDate = _findDateInMetadata(rows, bestHeaderRowIndex);
         if (metadataDate != null) {
            rowData[ExcelSchema.date] = metadataDate;
            hasData = true; // Count this as valid data row? Maybe not if only date.
         }
      }

      // Only add if we found meaningful data (ignore empty rows)
      if (hasData && (rowData.length > 1 || rowData.containsKey(ExcelSchema.ph))) {
        result.add(rowData);
      }
    }

    return result;
  }

  static int _countSchemaMatches(List<Data?> row) {
    int count = 0;
    for (var cell in row) {
      if (cell?.value != null) {
        if (ExcelSchema.match(cell!.value.toString()) != null) {
          count++;
        }
      }
    }
    return count;
  }

  static dynamic _parseValue(dynamic value) {
    if (value == null) return null;
    if (value is double || value is int) return value;
    if (value is DateCellValue) return value.asDateTimeLocal();
    if (value is DateTime) return value;
    
    final str = value.toString().trim();
    if (str.isEmpty) return null;

    final numVal = double.tryParse(str);
    if (numVal != null) return numVal;

    final dateVal = DateTime.tryParse(str);
    if (dateVal != null) return dateVal;

    return str; // Return string as last resort
  }

  // Look for "Date: 2023-01-01" type cells above the header row
  static DateTime? _findDateInMetadata(List<List<Data?>> rows, int headerRowIndex) {
    for (int i = 0; i < headerRowIndex; i++) {
      for (var cell in rows[i]) {
         if (cell?.value != null) {
            final str = cell!.value.toString().toLowerCase();
            if (str.contains('date')) {
                // Check next cell?
               // Simplified for now, just regex checking could be better
            }
         }
      }
    }
    return null; // TODO: Implement robust metadata scraping if column is missing
  }
}
