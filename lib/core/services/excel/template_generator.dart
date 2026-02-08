// import 'dart:io'; 
import 'package:excel/excel.dart';
import 'schema_definition.dart';

/// Generates a standardized Excel template for users to fill out.
class TemplateGenerator {
  
  /// Creates the template bytes.
  static List<int>? generate() {
    var excel = Excel.createExcel();
    
    // Rename default sheet
    String sheetName = 'Daily Report';
    excel.rename('Sheet1', sheetName);
    Sheet sheet = excel[sheetName];

    // 1. Add Metadata (Optional but helpful)
    _writeCell(sheet, 0, 0, 'Report Date:');
    _writeCell(sheet, 0, 1, DateTime.now().toIso8601String().substring(0, 10)); // Default to today

    // 2. Add Header Row
    int headerRow = 2; // Leave some space
    
    List<String> headers = [
      ExcelSchema.date,
      ExcelSchema.ph,
      'Alkalinity (ppm)', // Keeping readable names for template, or should we use canonical? 
      // The schema normalizer maps synonyms. 'Alkalinity (ppm)' contains 'alkalinity', so it works.
      'Conductivity (µS/cm)', // contains 'conductivity'
      'Total Hardness (ppm)', // contains 'hardness'
      'Chloride (ppm)',      // contains 'chloride'
      'Zinc (ppm)',          // contains 'zinc'
      'Iron (ppm)',          // contains 'iron'
      'Phosphates (ppm)',    // contains 'phosphates'
      'RO Free Chlorine (ppm)',
      'RO Silica (ppm)', 
      'RO Conductivity (µS/cm)'
    ];

    for (int i = 0; i < headers.length; i++) {
      _writeCell(sheet, i, headerRow, headers[i], isHeader: true);
    }

    // 3. Add Example Row
    int dataRow = 3;
    List<dynamic> exampleData = [
      DateTime.now().toIso8601String().substring(0, 10),
      7.8, // pH
      250, // Alk
      2400,// Cond
      320, // Hard
      450, // Cl
      1.2, // Zn
      0.1, // Fe
      8.0, // PO4
      0.02,// Free Cl
      45.0,// Silica
      15.0 // RO Cond
    ];

    for (int i = 0; i < exampleData.length; i++) {
        _writeCell(sheet, i, dataRow, exampleData[i]);
    }
    
    // 4. Add Notes
    _writeCell(sheet, 0, 5, 'NOTE: Please do not change the header names. You can add more rows for historical data.');

    return excel.encode();
  }

  static void _writeCell(Sheet sheet, int col, int row, dynamic value, {bool isHeader = false}) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = value;
      
      if (isHeader) {
        // Simple styling if possible, but we don't rely on it.
        // excel 2.0.0 might differ in styling API, keeping it simple.
      }
  }
}
