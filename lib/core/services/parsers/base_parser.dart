import 'package:excel/excel.dart';

/// Mixin to handle shared chemical column parsing
/// Maps Excel columns (C, D, E...) to internal data keys
mixin ChemicalParserMixin {
  /// Maps column index (0-based) to data key
  /// Based on specification (excel_template_spec.md):
  /// A (0) -> Date (handled by parser)
  /// B (1) -> pH
  /// C (2) -> Alkalinity
  /// D (3) -> Conductivity
  /// E (4) -> Hardness
  /// F (5) -> Chloride
  /// G (6) -> Zinc
  /// H (7) -> Iron
  /// I (8) -> Phosphate
  final Map<int, String> _columnMap = {
    1: 'ph',
    2: 'alkalinity',
    3: 'conductivity',
    4: 'hardness',
    5: 'chloride',
    6: 'zinc',
    7: 'iron',
    8: 'phosphates',
  };

  /// Extracts chemical data from a row
  Map<String, dynamic> parseChemicalData(List<Data?> row) {
    final Map<String, dynamic> data = {};

    _columnMap.forEach((colIndex, key) {
      if (colIndex < row.length) {
        final cell = row[colIndex];
        if (cell != null && cell.value != null) {
          final value = _parseValue(cell.value);
          if (value != null) {
            data[key] = value;
          }
        }
      }
    });

    return data;
  }

  dynamic _parseValue(dynamic value) {
    if (value is double || value is int) {
      return value;
    }
    if (value is String) {
      return double.tryParse(value.trim()); // Attempt to convert strings to numbers
    }
    return null;
  }
}
