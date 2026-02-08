import 'dart:io';
import 'package:excel/excel.dart';
import '../models/chemistry_models.dart';
import 'calculation_engine.dart';

class ExcelService {
  static Future<Map<String, dynamic>> parseExcel(String filePath) async {
    var bytes = File(filePath).readAsBytesSync();
    return parseExcelBytes(bytes);
  }

  static Future<Map<String, dynamic>> parseExcelBytes(List<int> bytes) async {
    var excel = Excel.decodeBytes(bytes);

    CoolingTowerData? coolingTowerData;
    ROData? roData;

    // Parse Entry (Cooling Tower) sheet
    var entrySheet = excel.tables['Entry'];
    
    // Fallback to 'Sheet1' if 'Entry' is missing
    if (entrySheet == null) {
      print('DEBUG: "Entry" sheet not found. Available sheets: ${excel.tables.keys.toList()}');
      if (excel.tables.containsKey('Sheet1')) {
        entrySheet = excel.tables['Sheet1'];
        print('DEBUG: Using "Sheet1" instead.');
      }
    }

    if (entrySheet != null) {
      // 1. Safe debug dump
      print('DEBUG: --- EXCEL CONTENT DUMP ---');
      final rows = entrySheet.rows;
      for (int i = 0; i < rows.length && i < 5; i++) {
         final row = rows[i];
         print('Row $i: ${row.map((e) => e?.value).toList()}');
      }
      print('DEBUG: --------------------------');

      // 2. Helper to find value by keywords (Smart Parse)
      double getValue(List<String> keywords) {
        if (entrySheet == null) return 0.0;
        for (final row in entrySheet!.rows) {
          if (row.isEmpty) continue;
          for (int i = 0; i < row.length; i++) {
            final cell = row[i];
            if (cell == null) continue;
            
            final cellValueStr = cell.value?.toString().toLowerCase() ?? '';
            if (keywords.any((k) => cellValueStr.contains(k.toLowerCase()))) {
              // Found keyword, look for first numeric value in subsequent cells
              for (int j = i + 1; j < row.length; j++) {
                final potentialVal = row[j]?.value;
                if (potentialVal != null) {
                  final parsed = double.tryParse(potentialVal.toString().trim());
                  if (parsed != null) return parsed;
                }
              }
            }
          }
        }
        return 0.0;
      }

      print('DEBUG: Running Smart Parser...');
      if (entrySheet == null) {
         print('DEBUG: CRITICAL ERROR: entrySheet is null before Smart Parser loop');
      }
      
      // Extract Date
      DateTime reportDate = DateTime.now();
      for (final row in entrySheet.rows) {
        for (int i = 0; i < row.length; i++) {
          final cell = row[i];
          if (cell == null) continue;
          final valStr = cell.value?.toString().toLowerCase() ?? '';
          // print('DEBUG: Checking cell $i: $valStr');
          if (valStr.contains('date')) {
            // Check current cell or next cell for date value
            final possibleDate = (i + 1 < row.length) ? row[i+1]?.value : cell.value;
            if (possibleDate != null) {
              if (possibleDate is DateCellValue) {
                reportDate = possibleDate.asDateTimeLocal();
                break;
              } else {
                final parsed = DateTime.tryParse(possibleDate.toString());
                if (parsed != null) {
                  reportDate = parsed;
                  break;
                }
              }
            }
          }
        }
        if (reportDate.year != DateTime.now().year || reportDate.month != DateTime.now().month || reportDate.day != DateTime.now().day) {
           // If we found a date that isn't exactly today, assume we found it.
           // (This is a bit loose but works for older reports)
           break; 
        }
      }
      print('DEBUG: Detected Report Date: $reportDate');

      var ph = getValue(['pH', 'ph value']);
      var alk = getValue(['alkalinity', 'm-alk', 'total alk']);
      var hard = getValue(['hardness', 'total hardness', 'th']);
      var cond = getValue(['conductivity', 'cond', 'ec']);
      var cl = getValue(['chloride', 'cl-', 'cl']);
      var zn = getValue(['zinc', 'zn']);
      var fe = getValue(['iron', 'fe', 'total iron']);
      var po4 = getValue(['phosphate', 'po4', 'ortho']);

      // 3. Fallback: Strict Row 1 Parser
      if (ph <= 0 && entrySheet.rows.length > 1) {
         print('DEBUG: Smart Parser failed (pH=0). Falling back to Strict Row 1 Parser...');
         final row = entrySheet.rows[1]; 
         if (row.length > 8) {
            ph = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
            alk = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
            cond = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
            hard = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
            cl = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
            zn = double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0;
            fe = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
            po4 = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0;
         }
      }
      
      coolingTowerData = CoolingTowerData(
        ph: WaterParameter(
          name: 'pH', 
          value: ph, 
          unit: 'pH', 
          optimalMin: 7.0, 
          optimalMax: 8.5,
          quality: CalculationEngine.validateParameter(ph, 7.0, 8.5),
        ),
        alkalinity: WaterParameter(
          name: 'Total Alkalinity', 
          value: alk, 
          unit: 'ppm', 
          optimalMin: 100, 
          optimalMax: 500,
          quality: CalculationEngine.validateParameter(alk, 100, 500),
        ),
        conductivity: WaterParameter(
          name: 'Conductivity', 
          value: cond, 
          unit: 'µS/cm', 
          optimalMin: 500, 
          optimalMax: 3000,
          quality: CalculationEngine.validateParameter(cond, 500, 3000),
        ),
        totalHardness: WaterParameter(
          name: 'Total Hardness', 
          value: hard, 
          unit: 'ppm', 
          optimalMin: 50, 
          optimalMax: 400,
          quality: CalculationEngine.validateParameter(hard, 50, 400),
        ),
        chloride: WaterParameter(
          name: 'Chloride', 
          value: cl, 
          unit: 'ppm',
          quality: CalculationEngine.validateParameter(cl, null, 250),
        ),
        zinc: WaterParameter(
          name: 'Zinc', 
          value: zn, 
          unit: 'ppm',
          quality: CalculationEngine.validateParameter(zn, 0.5, 2.0),
        ),
        iron: WaterParameter(
          name: 'Iron', 
          value: fe, 
          unit: 'ppm',
          quality: CalculationEngine.validateParameter(fe, null, 0.5),
        ),
        phosphates: WaterParameter(
          name: 'Phosphates', 
          value: po4, 
          unit: 'ppm',
          quality: CalculationEngine.validateParameter(po4, 5, 15),
        ),
        timestamp: reportDate,
      );
      print('DEBUG: Final Parse Result - pH: ${coolingTowerData.ph.value}, Alk: ${coolingTowerData.alkalinity.value}');
    }

    // Parse RO sheet
    var roSheet = excel.tables['RO'];
    if (roSheet != null && roSheet.rows.length > 1) {
      var row = roSheet.rows[1];
      if (row.length > 3) {
        final freeChValue = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
        final silicaValue = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
        final roCondValue = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
        
        roData = ROData(
          freeChlorine: WaterParameter(
            name: 'Free Chlorine',
            value: freeChValue,
            unit: 'ppm',
            optimalMin: 0,
            optimalMax: 0.1,
            quality: CalculationEngine.validateParameter(freeChValue, 0, 0.1),
          ),
          silica: WaterParameter(
            name: 'Silica',
            value: silicaValue,
            unit: 'ppm',
            optimalMin: 0,
            optimalMax: 150,
            quality: CalculationEngine.validateParameter(silicaValue, 0, 150),
          ),
          roConductivity: WaterParameter(
            name: 'RO Conductivity',
            value: roCondValue,
            unit: 'µS/cm',
            optimalMin: 0,
            optimalMax: 50,
            quality: CalculationEngine.validateParameter(roCondValue, 0, 50),
          ),
          timestamp: DateTime.now(),
        );
      }
    }

    return {
      'coolingTower': coolingTowerData,
      'ro': roData,
    };
  }
}
