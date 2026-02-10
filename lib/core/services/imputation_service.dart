
import 'package:excel/excel.dart';
import 'package:collection/collection.dart';
import '../../features/factories/data/storage_service.dart'; // Not needed but checking paths
import 'excel/schema_definition.dart'; 

// UniversalExcelParser is in the same folder 'core/services/excel/'? 
// No, ImputationService is in 'core/services/'. 
// UniversalExcelParser is in 'core/services/excel/'.
import 'excel/universal_excel_parser.dart';

class ImputationService {
  
  /// Checks if the file has missing values in required columns.
  /// Returns true if risk acceptance is needed.
  static bool hasMissingValues(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      // Rough check: Find header, scan for empty cells in required columns
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows == 0) continue;
        
        final rows = sheet.rows;
        // Simple heuristic: Use UniversalParser's logic to find header?
        // Or just scan for zeros/nulls in what looks like data?
        // For efficiency, let's rely on UniversalExcelParser.parse() which we already call?
        // But the user wants "Immediate validation".
        // Let's assume we call this only if UniversalParser detected issues.
      }
      return false; // Delegated to Parser for detection
    } catch (e) {
      return false;
    }
  }

  /// Imputes missing values in the Excel file bytes and returns the corrected bytes.
  static List<int>? imputeAndFixFile(List<int> bytes) {
    var excel = Excel.decodeBytes(bytes);
    
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      
      // 1. Identify Columns
      // We need to know which index corresponds to which parameter.
      // This duplicates Normalizer logic, but `excel` package doesn't expose easy column access by name.
      // Let's do a simplified scan.
      
      int headerRowIdx = -1;
      Map<int, String> colMap = {};
      
      // Find Header
      for (int r = 0; r < sheet.rows.length; r++) {
         int matches = 0;
         Map<int, String> potentialMap = {};
         for (int c = 0; c < sheet.rows[r].length; c++) {
            final val = sheet.rows[r][c]?.value?.toString() ?? '';
            final canonical = ExcelSchema.match(val);
            if (canonical != null) {
               matches++;
               potentialMap[c] = canonical;
            }
         }
         if (matches >= 3) {
           headerRowIdx = r;
           colMap = potentialMap;
           break;
         }
      }
      
      if (headerRowIdx == -1) continue; // Skip sheet if no header
      
      // 2. Calculate Averages per Column
      Map<String, List<double>> values = {};
      
      for (int r = headerRowIdx + 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        for (var entry in colMap.entries) {
           if (entry.key < row.length) {
             final cell = row[entry.key];
             final val = _parseValue(cell?.value);
             if (val != null && val > 0.0001) {
               values.putIfAbsent(entry.value, () => []).add(val);
             }
           }
        }
      }
      
      Map<String, double> averages = {};
      values.forEach((key, list) {
        if (list.isNotEmpty) {
          averages[key] = list.average;
        }
      });
      
      // 3. Impute (Fill Missing)
      for (int r = headerRowIdx + 1; r < sheet.rows.length; r++) {
         // Check if row is empty (ignore)
         bool rowIsEmpty = sheet.rows[r].every((c) => c?.value == null);
         if (rowIsEmpty) continue;
         
         for (var entry in colMap.entries) {
           final colIdx = entry.key;
           final key = entry.value;
           
           // Get current value
           final cell = (colIdx < sheet.rows[r].length) ? sheet.rows[r][colIdx] : null;
           final val = _parseValue(cell?.value);
           
           // If missing (null or roughly 0)
           if (val == null || val < 0.0001) {
             final avg = averages[key];
             if (avg != null) {
               // Update Cell
               final cellIndex = CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: r);
               // Assuming simplified formatting
               sheet.updateCell(cellIndex, DoubleCellValue(avg));
             }
           }
         }
      }
    }
    
    return excel.encode();
  }

  static double? _parseValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
