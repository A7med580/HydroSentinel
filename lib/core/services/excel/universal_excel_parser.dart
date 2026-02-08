// import 'dart:io';
import 'package:excel/excel.dart';
import '../../../../models/chemistry_models.dart';
import '../../../../services/calculation_engine.dart';
import 'excel_normalizer.dart';
import 'excel_validator.dart';
import 'schema_definition.dart';

/// The main entry point for robust Excel ingestion.
/// Orchestrates Normalization -> Validation -> Domain Mapping.
class UniversalExcelParser {
  
  static Future<Map<String, dynamic>> parse(List<int> bytes) async {
    var excel = Excel.decodeBytes(bytes);
    
    // 1. Find the best sheet (usually 'Entry' or first visible)
    Sheet? sheet = excel.tables['Entry'];
    if (sheet == null) {
      // Fallback to first non-empty sheet
      for (var table in excel.tables.keys) {
        if (excel.tables[table]!.maxRows > 0) {
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
    
    // 3. Validate
    ExcelValidator.validateDataset(normalizedRows);

    // 4. Map to Domain Models
    // For now, we assume the file represents ONE report (the latest one or first row).
    // Future: Support multi-row historical import.
    final latestRow = normalizedRows.first; // TODO: or sort by date?

    // Validate Row Specifics
    final errors = ExcelValidator.validateRow(latestRow);
    if (errors.isNotEmpty) {
      throw FormatException('Validation Failed: ${errors.join(", ")}');
    }

    return _mapToDomain(latestRow);
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
    final ctData = CoolingTowerData(
      ph: _createParam('pH', val(ExcelSchema.ph), 'pH', 7.0, 8.5),
      alkalinity: _createParam('Alk', val(ExcelSchema.alkalinity), 'ppm', 100, 500),
      conductivity: _createParam('Cond', val(ExcelSchema.conductivity), 'µS/cm', 500, 3000),
      totalHardness: _createParam('Hard', val(ExcelSchema.hardness), 'ppm', 50, 400),
      chloride: _createParam('Cl', val(ExcelSchema.chloride), 'ppm', 0, 250),
      zinc: _createParam('Zn', val(ExcelSchema.zinc), 'ppm', 0.5, 2.0),
      iron: _createParam('Fe', val(ExcelSchema.iron), 'ppm', 0, 0.5),
      phosphates: _createParam('PO4', val(ExcelSchema.phosphate), 'ppm', 5, 15),
      timestamp: date,
    );

    // RO Data (if exists in same row or separate logic needed?)
    // Assuming RO might be in the same row if headers are unique.
    // If RO is on a separate sheet, we need to normalize that sheet too.
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
