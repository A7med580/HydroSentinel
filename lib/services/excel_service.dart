import 'dart:io';
import 'package:excel/excel.dart';
import '../models/chemistry_models.dart';
import 'calculation_engine.dart';

class ExcelService {
  static Future<Map<String, dynamic>> parseExcel(String filePath) async {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    CoolingTowerData? coolingTowerData;
    ROData? roData;

    // Parse Entry (Cooling Tower) sheet
    var entrySheet = excel.tables['Entry'];
    if (entrySheet != null) {
      var row = entrySheet.rows[1]; // Assume second row has latest data
      coolingTowerData = CoolingTowerData(
        ph: WaterParameter(
          name: 'pH',
          value: double.tryParse(row[1]?.value.toString() ?? '0') ?? 0,
          unit: 'pH',
          optimalMin: 7.0,
          optimalMax: 8.5,
          quality: CalculationEngine.validateParameter(double.tryParse(row[1]?.value.toString() ?? '0') ?? 0, 7.0, 8.5),
        ),
        alkalinity: WaterParameter(
          name: 'Total Alkalinity',
          value: double.tryParse(row[2]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 100,
          optimalMax: 500,
          quality: CalculationEngine.validateParameter(double.tryParse(row[2]?.value.toString() ?? '0') ?? 0, 100, 500),
        ),
        conductivity: WaterParameter(
          name: 'Conductivity',
          value: double.tryParse(row[3]?.value.toString() ?? '0') ?? 0,
          unit: 'µS/cm',
          optimalMin: 500,
          optimalMax: 3000,
          quality: CalculationEngine.validateParameter(double.tryParse(row[3]?.value.toString() ?? '0') ?? 0, 500, 3000),
        ),
        totalHardness: WaterParameter(
          name: 'Total Hardness',
          value: double.tryParse(row[4]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 50,
          optimalMax: 400,
          quality: CalculationEngine.validateParameter(double.tryParse(row[4]?.value.toString() ?? '0') ?? 0, 50, 400),
        ),
        chloride: WaterParameter(
          name: 'Chloride',
          value: double.tryParse(row[5]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 250,
          quality: CalculationEngine.validateParameter(double.tryParse(row[5]?.value.toString() ?? '0') ?? 0, 0, 250),
        ),
        zinc: WaterParameter(
          name: 'Zinc',
          value: double.tryParse(row[6]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 0.5,
          optimalMax: 2.0,
          quality: CalculationEngine.validateParameter(double.tryParse(row[6]?.value.toString() ?? '0') ?? 0, 0.5, 2.0),
        ),
        iron: WaterParameter(
          name: 'Iron',
          value: double.tryParse(row[7]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 0.5,
          quality: CalculationEngine.validateParameter(double.tryParse(row[7]?.value.toString() ?? '0') ?? 0, 0, 0.5),
        ),
        phosphates: WaterParameter(
          name: 'Phosphates',
          value: double.tryParse(row[8]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 5,
          optimalMax: 15,
          quality: CalculationEngine.validateParameter(double.tryParse(row[8]?.value.toString() ?? '0') ?? 0, 5, 15),
        ),
        timestamp: DateTime.now(),
      );
    }

    // Parse RO sheet
    var roSheet = excel.tables['RO'];
    if (roSheet != null) {
      var row = roSheet.rows[1];
      roData = ROData(
        freeChlorine: WaterParameter(
          name: 'Free Chlorine',
          value: double.tryParse(row[1]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 0.1,
          quality: CalculationEngine.validateParameter(double.tryParse(row[1]?.value.toString() ?? '0') ?? 0, 0, 0.1),
        ),
        silica: WaterParameter(
          name: 'Silica',
          value: double.tryParse(row[2]?.value.toString() ?? '0') ?? 0,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 150,
          quality: CalculationEngine.validateParameter(double.tryParse(row[2]?.value.toString() ?? '0') ?? 0, 0, 150),
        ),
        roConductivity: WaterParameter(
          name: 'RO Conductivity',
          value: double.tryParse(row[3]?.value.toString() ?? '0') ?? 0,
          unit: 'µS/cm',
          optimalMin: 0,
          optimalMax: 50,
          quality: CalculationEngine.validateParameter(double.tryParse(row[3]?.value.toString() ?? '0') ?? 0, 0, 50),
        ),
        timestamp: DateTime.now(),
      );
    }

    return {
      'coolingTower': coolingTowerData,
      'ro': roData,
    };
  }
}
