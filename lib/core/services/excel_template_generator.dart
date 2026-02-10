import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'excel/schema_definition.dart';

class ExcelTemplateGenerator {
  
  /// Generates a sample Excel file and opens the share dialog.
  static Future<void> generateAndShare() async {
    final excel = Excel.createExcel();
    
    // Rename default sheet
    final Sheet sheet = excel['Sheet1'];
    excel.rename('Sheet1', 'Entry'); // Standardize on 'Entry'
    
    // 1. Add Headers (Bold)
    final headers = [
      'Date', 'pH', 'Alkalinity', 'Conductivity', 'Total Hardness', 'Chloride', 
      'Temperature', 'Zinc', 'Iron', 'Phosphate', 'Sulfate',
      'Free Chlorine', 'Silica', 'RO Conductivity'
    ];
    
    // CellStyle for header
    CellStyle headerStyle = CellStyle(
      bold: true, 
      fontFamily: getFontFamily(FontFamily.Calibri),
    );

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // 2. Add Sample Data
    final now = DateTime.now();
    final sampleData = [
      [
        DateCellValue(year: now.year, month: now.month, day: now.day), 
        DoubleCellValue(7.8), DoubleCellValue(120), DoubleCellValue(1500), DoubleCellValue(250), DoubleCellValue(150),
        DoubleCellValue(35), DoubleCellValue(1.8), DoubleCellValue(0.2), DoubleCellValue(10), DoubleCellValue(75),
        DoubleCellValue(0.05), DoubleCellValue(12), DoubleCellValue(25),
      ],
      [
        DateCellValue(year: now.year, month: now.month, day: now.day - 1), 
        DoubleCellValue(8.0), DoubleCellValue(110), DoubleCellValue(1550), DoubleCellValue(260), DoubleCellValue(160),
        DoubleCellValue(36), DoubleCellValue(1.5), DoubleCellValue(0.3), DoubleCellValue(8), DoubleCellValue(80),
        DoubleCellValue(0.08), DoubleCellValue(15), DoubleCellValue(28),
      ],
      [
        DateCellValue(year: now.year, month: now.month, day: now.day - 2), 
        DoubleCellValue(7.6), DoubleCellValue(130), DoubleCellValue(1450), DoubleCellValue(240), DoubleCellValue(140),
        DoubleCellValue(34), DoubleCellValue(2.0), DoubleCellValue(0.1), DoubleCellValue(12), DoubleCellValue(70),
        DoubleCellValue(0.02), DoubleCellValue(10), DoubleCellValue(22),
      ],
    ];

    for (int r = 0; r < sampleData.length; r++) {
       for (int c = 0; c < sampleData[r].length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          cell.value = sampleData[r][c];
       }
    }

    // 3. Save to temporary file
    final List<int>? fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/HydroSentinel_Template.xlsx';
    final File file = File(path);
    await file.writeAsBytes(fileBytes);

    // 4. Share
    await Share.shareXFiles([XFile(path)], text: 'Basic HydroSentinel Excel Template');
  }
}
