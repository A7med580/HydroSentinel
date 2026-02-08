import 'dart:io';
import 'package:excel/excel.dart';
import '../models/chemistry_models.dart';
import '../models/analytics_models.dart';
import '../models/assessment_models.dart';
import 'calculation_engine.dart';

class ExcelService {
  static Future<Map<String, dynamic>> parseExcel(String filePath) async {
    var bytes = File(filePath).readAsBytesSync();
    return parseExcelBytes(bytes);
  }

  /// Parse Excel file and return list of measurements (supports multi-date files)
  static Future<Map<String, dynamic>> parseExcelBytes(List<int> bytes) async {
    var excel = Excel.decodeBytes(bytes);

    // Find Entry sheet
    var entrySheet = excel.tables['Entry'] ?? excel.tables['Sheet1'];
    
    if (entrySheet == null) {
      print('DEBUG: No valid sheet found. Available: ${excel.tables.keys.toList()}');
      return {'measurements': <WaterMeasurement>[]};
    }

    print('DEBUG: --- EXCEL CONTENT DUMP ---');
    for (int i = 0; i < entrySheet.maxRows && i < 5; i++) {
       print('Row $i: ${entrySheet.rows[i].map((e) => e?.value).toList()}');
    }
    print('DEBUG: --------------------------');

    // Detect column layout
    final headerRow = entrySheet.rows[0];
    final columnMap = _mapColumns(headerRow);
    
    print('DEBUG: Column map: $columnMap');

    List<WaterMeasurement> measurements = [];
    
    // Parse each data row (skip header)
    for (int rowIndex = 1; rowIndex < entrySheet.maxRows; rowIndex++) {
      final row = entrySheet.rows[rowIndex];
      
      try {
        final measurement = _parseRow(row, columnMap, rowIndex);
        if (measurement != null) {
          measurements.add(measurement);
        }
      } catch (e) {
        print('WARNING: Skipped row $rowIndex: $e');
      }
    }

    print('DEBUG: Parsed ${measurements.length} measurements');

    // Parse RO sheet (if exists)
    await _parseROSheet(excel, measurements);

    // Backward compatibility: also return single measurement
    CoolingTowerData? singleCT;
    ROData? singleRO;
    if (measurements.isNotEmpty) {
      singleCT = measurements.last.ctData;
      singleRO = measurements.last.roData;
    }

    return {
      'measurements': measurements,
      'coolingTower': singleCT, // Backward compat
      'ro': singleRO,           // Backward compat
    };
  }

  /// Map column headers to indices
  static Map<String, int> _mapColumns(List<Data?> headerRow) {
    Map<String, int> map = {};
    
    for (int i = 0; i < headerRow.length; i++) {
      final header = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
      
      // Date column
      if (header.contains('date') || header.contains('sample')) {
        map['date'] = i;
      }
      // Parameters
      else if (header.contains('ph')) map['ph'] = i;
      else if (header.contains('alk')) map['alkalinity'] = i;
      else if (header.contains('cond') || header.contains('ec')) map['conductivity'] = i;
      else if (header.contains('hard')) map['hardness'] = i;
      else if (header.contains('chloride') || header == 'cl') map['chloride'] = i;
      else if (header.contains('zinc') || header == 'zn') map['zinc'] = i;
      else if (header.contains('iron') || header == 'fe') map['iron'] = i;
      else if (header.contains('phos') || header.contains('po4')) map['phosphates'] = i;
    }
    
    return map;
  }

  /// Parse a single row into WaterMeasurement
  static WaterMeasurement? _parseRow(List<Data?> row, Map<String, int> columnMap, int rowIndex) {
    // Extract date
    DateTime measurementDate = DateTime.now();
    if (columnMap.containsKey('date')) {
      final dateCell = row[columnMap['date']!]?.value;
      measurementDate = _parseDate(dateCell) ?? DateTime.now();
    }

    // Extract parameters
    double getValue(String key) {
      if (!columnMap.containsKey(key)) return 0.0;
      final cell = row[columnMap[key]!]?.value;
      if (cell == null) return 0.0;
      return double.tryParse(cell.toString()) ?? 0.0;
    }

    final ph = getValue('ph');
    final alk = getValue('alkalinity');
    final cond = getValue('conductivity');
    final hard = getValue('hardness');
    final cl = getValue('chloride');
    final zn = getValue('zinc');
    final fe = getValue('iron');
    final po4 = getValue('phosphates');

    // Validate: require at minimum pH and alkalinity
    if (ph <= 0 && alk <= 0) {
      print('DEBUG: Skipping row $rowIndex (missing critical params)');
      return null;
    }

    // Build CoolingTowerData
    final ctData = CoolingTowerData(
      ph: WaterParameter(name: 'pH', value: ph, unit: 'pH', optimalMin: 7.0, optimalMax: 8.5),
      alkalinity: WaterParameter(name: 'Total Alkalinity', value: alk, unit: 'ppm', optimalMin: 100, optimalMax: 500),
      conductivity: WaterParameter(name: 'Conductivity', value: cond, unit: 'µS/cm', optimalMin: 500, optimalMax: 3000),
      totalHardness: WaterParameter(name: 'Total Hardness', value: hard, unit: 'ppm', optimalMin: 50, optimalMax: 400),
      chloride: WaterParameter(name: 'Chloride', value: cl, unit: 'ppm'),
      zinc: WaterParameter(name: 'Zinc', value: zn, unit: 'ppm'),
      iron: WaterParameter(name: 'Iron', value: fe, unit: 'ppm'),
      phosphates: WaterParameter(name: 'Phosphates', value: po4, unit: 'ppm'),
      timestamp: measurementDate,
    );

    // Calculate indices and risk
    final indices = CalculationEngine.calculateIndices(ctData);
    final risk = CalculationEngine.assessRisk(indices, ctData);

    return WaterMeasurement(
      id: '', // Will be set by database
      factoryId: '', // Will be set by caller
      measurementDate: measurementDate,
      ctData: ctData,
      roData: null, // Will be matched later
      indices: indices,
      risk: risk,
      sourceFileId: '', // Will be set by caller
      sourceFileName: '', // Will be set by caller
      uploadedAt: DateTime.now(),
    );
  }

  /// Parse date from various formats
  static DateTime? _parseDate(dynamic cellValue) {
    if (cellValue == null) return null;
    
    // Excel serial date number
    if (cellValue is num) {
      try {
        // Excel epoch is 1899-12-30
        final excelEpoch = DateTime(1899, 12, 30);
        return excelEpoch.add(Duration(days: cellValue.toInt()));
      } catch (e) {
        print('DEBUG: Failed to parse Excel date: $e');
        return null;
      }
    }

    final dateStr = cellValue.toString().trim();
    
    // Try ISO format: 2024-03-15
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    // Try MM/DD/YYYY
    final mmddyyyyPattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final mmddyyyyMatch = mmddyyyyPattern.firstMatch(dateStr);
    if (mmddyyyyMatch != null) {
      final month = int.parse(mmddyyyyMatch.group(1)!);
      final day = int.parse(mmddyyyyMatch.group(2)!);
      final year = int.parse(mmddyyyyMatch.group(3)!);
      return DateTime(year, month, day);
    }

    // Try DD-MM-YYYY
    final ddmmyyyyPattern = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');
    final ddmmyyyyMatch = ddmmyyyyPattern.firstMatch(dateStr);
    if (ddmmyyyyMatch != null) {
      final day = int.parse(ddmmyyyyMatch.group(1)!);
      final month = int.parse(ddmmyyyyMatch.group(2)!);
      final year = int.parse(ddmmyyyyMatch.group(3)!);
      return DateTime(year, month, day);
    }

    print('DEBUG: Unrecognized date format: $dateStr');
    return null;
  }

  /// Parse RO sheet and match to measurements by date
  static Future<void> _parseROSheet(Excel excel, List<WaterMeasurement> measurements) async {
    var roSheet = excel.tables['RO'];
    if (roSheet == null) return;

    // Map dates to RO data
    Map<String, ROData> roDataMap = {};

    for (int i = 1; i < roSheet.maxRows; i++) {
      final row = roSheet.rows[i];
      if (row.isEmpty) continue;

      // Extract date and RO parameters
      final dateCell = row[0]?.value;
      final date = _parseDate(dateCell);
      if (date == null) continue;

      final freeChlorine = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
      final silica = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
      final roCond = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;

      roDataMap[date.toIso8601String().split('T')[0]] = ROData(
        freeChlorine: WaterParameter(
          name: 'Free Chlorine',
          value: freeChlorine,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 0.1,
          quality: CalculationEngine.validateParameter(freeChlorine, 0, 0.1),
        ),
        silica: WaterParameter(
          name: 'Silica',
          value: silica,
          unit: 'ppm',
          optimalMin: 0,
          optimalMax: 150,
          quality: CalculationEngine.validateParameter(silica, 0, 150),
        ),
        roConductivity: WaterParameter(
          name: 'RO Conductivity',
          value: roCond,
          unit: 'µS/cm',
          optimalMin: 0,
          optimalMax: 50,
          quality: CalculationEngine.validateParameter(roCond, 0, 50),
        ),
        timestamp: date,
      );
    }

    // Match RO data to measurements
    for (var measurement in measurements) {
      final dateKey = measurement.measurementDate.toIso8601String().split('T')[0];
      if (roDataMap.containsKey(dateKey)) {
        // Create new measurement with RO data
        final index = measurements.indexOf(measurement);
        measurements[index] = WaterMeasurement(
          id: measurement.id,
          factoryId: measurement.factoryId,
          measurementDate: measurement.measurementDate,
          ctData: measurement.ctData,
          roData: roDataMap[dateKey],
          indices: measurement.indices,
          risk: measurement.risk,
          sourceFileId: measurement.sourceFileId,
          sourceFileName: measurement.sourceFileName,
          uploadedAt: measurement.uploadedAt,
        );
      }
    }
  }
}
