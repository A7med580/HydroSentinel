// import 'dart:io';
import 'package:excel/excel.dart';
import '../../../../models/chemistry_models.dart';
import '../../../../services/calculation_engine.dart';
import 'excel_normalizer.dart';
import 'excel_validator.dart';
import 'schema_definition.dart';

/// The main entry point for robust Excel ingestion.
/// Orchestrates Normalization -> Validation -> Domain Mapping.
/// NOW SUPPORTS MULTI-ROW FILES (e.g., monthly data with 31 rows)
class UniversalExcelParser {
  
  /// Parse Excel bytes and return ALL measurements (not just first row)
  static Future<Map<String, dynamic>> parse(List<int> bytes) async {
    try {
      var excel = Excel.decodeBytes(bytes);
    
    // 1. Find the best sheet (usually 'Entry' or first visible)
    Sheet? sheet = excel.tables['Entry'];
    if (sheet == null) {
      // Fallback to first non-empty sheet
      for (var table in excel.tables.keys) {
        if ((excel.tables[table]?.maxRows ?? 0) > 0) {
          sheet = excel.tables[table];
          break;
        }
      }
    }

    if (sheet == null) {
      throw const FormatException('Excel file is empty or unreadable.');
    }

    // 2. Normalize
    final normalizedRows = ExcelNormalizer.normalize(sheet);
    print('DEBUG: [UniversalParser] Normalized ${normalizedRows.length} rows');
    
    // 3. Validate dataset
    ExcelValidator.validateDataset(normalizedRows);

    // 4. Map ALL rows to Domain Models
    List<CoolingTowerData> allCTData = [];
    List<ROData> allROData = [];

    for (int i = 0; i < normalizedRows.length; i++) {
      final row = normalizedRows[i];
      
      // Validate row
      final errors = ExcelValidator.validateRow(row);
      if (errors.isNotEmpty) {
        print('WARNING: Skipping row $i: ${errors.join(", ")}');
        continue;
      }

      final result = _mapToDomain(row);
      
      final ctData = result['coolingTower'] as CoolingTowerData?;
      final roData = result['ro'] as ROData?;
      
      if (ctData != null) allCTData.add(ctData);
      if (roData != null) allROData.add(roData);
    }

    print('DEBUG: [UniversalParser] Parsed ${allCTData.length} CT measurements, ${allROData.length} RO measurements');

    // Sort by timestamp (oldest first)
    allCTData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    allROData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Backward compatibility: also return single latest measurement
    CoolingTowerData? latestCT = allCTData.isNotEmpty ? allCTData.last : null;
    ROData? latestRO = allROData.isNotEmpty ? allROData.last : null;

    // NEW: Collect validation metadata for missing data handling
    final List<String> missingParams = [];
    final List<int> rowsWithIssues = [];
    final requiredKeys = [ExcelSchema.ph, ExcelSchema.alkalinity, ExcelSchema.conductivity, 
                          ExcelSchema.hardness, ExcelSchema.chloride, ExcelSchema.date];
    
    for (int i = 0; i < normalizedRows.length; i++) {
      final row = normalizedRows[i];
      for (final key in requiredKeys) {
        if (!row.containsKey(key) || row[key] == null) {
          if (!missingParams.contains(key)) missingParams.add(key);
          if (!rowsWithIssues.contains(i)) rowsWithIssues.add(i);
        }
      }
    }

    return {
      // NEW: All measurements for multi-row support
      'allCTData': allCTData,
      'allROData': allROData,
      // BACKWARD COMPAT: Single values (latest measurement)
      'coolingTower': latestCT,
      'ro': latestRO,
      // NEW: Validation metadata for missing data handling
      'missingParameters': missingParams,
    };
    } catch (e, stack) {
      print('ERROR: [UniversalParser] Fatal Parse Error: $e');
      print(stack);
      rethrow;
    }
  }

  static Map<String, dynamic> _mapToDomain(Map<String, dynamic> row) {
    final date = _parseDate(row[ExcelSchema.date]) ?? DateTime.now();

    // Helper for safe extraction
    double val(String key) {
      final v = row[key];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    
    // Cooling Tower
    // Optional: temperature (Task 1.1) and sulfate (Task 1.3)
    WaterParameter? tempParam;
    if (row.containsKey(ExcelSchema.temperature) && row[ExcelSchema.temperature] != null) {
      final tempVal = val(ExcelSchema.temperature);
      if (tempVal >= 5 && tempVal <= 60) {
        tempParam = _createParam('Temp', tempVal, '°C', 20, 45);
      }
    }
    WaterParameter? sulfateParam;
    if (row.containsKey(ExcelSchema.sulfate) && row[ExcelSchema.sulfate] != null) {
      final sulfateVal = val(ExcelSchema.sulfate);
      if (sulfateVal >= 0) {
        sulfateParam = _createParam('SO4', sulfateVal, 'ppm', 0, 500);
      }
    }

    final ctData = CoolingTowerData(
      ph: _createParam('pH', val(ExcelSchema.ph), 'pH', 7.0, 8.5),
      alkalinity: _createParam('Alk', val(ExcelSchema.alkalinity), 'ppm', 100, 500),
      conductivity: _createParam('Cond', val(ExcelSchema.conductivity), 'µS/cm', 500, 3000),
      totalHardness: _createParam('Hard', val(ExcelSchema.hardness), 'ppm', 50, 400),
      chloride: _createParam('Cl', val(ExcelSchema.chloride), 'ppm', 0, 250),
      zinc: _createParam('Zn', val(ExcelSchema.zinc), 'ppm', 0.5, 2.0),
      iron: _createParam('Fe', val(ExcelSchema.iron), 'ppm', 0, 0.5),
      phosphates: _createParam('PO4', val(ExcelSchema.phosphate), 'ppm', 5, 15),
      temperature: tempParam,
      sulfate: sulfateParam,
      timestamp: date,
    );

    // RO Data (if exists in same row)
    ROData? roData;
    if (row.containsKey(ExcelSchema.freeChlorine) || row.containsKey(ExcelSchema.silica)) {
        roData = ROData(
          freeChlorine: _createParam('Free Cl', val(ExcelSchema.freeChlorine), 'ppm', 0, 0.1),
          silica: _createParam('Silica', val(ExcelSchema.silica), 'ppm', 0, 150),
          roConductivity: _createParam('RO Cond', val(ExcelSchema.roConductivity), 'µS/cm', 0, 50),
          timestamp: date,
        );
    }

    return {
      'coolingTower': ctData,
      'ro': roData,
    };
  }

  static WaterParameter _createParam(String name, double value, String unit, double min, double max) {
    return WaterParameter(
      name: name,
      value: value,
      unit: unit,
      optimalMin: min,
      optimalMax: max,
      quality: CalculationEngine.validateParameter(value, min, max),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
