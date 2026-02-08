import 'schema_definition.dart';
// import '../../../../models/chemistry_models.dart';

/// Enforces data integrity rules on the normalized data.
class ExcelValidator {
  
  /// Validates a single row of data against the schema.
  /// Returns a list of error messages (empty if valid).
  static List<String> validateRow(Map<String, dynamic> row) {
    final errors = <String>[];

    // RULE 1: Critical Parameters must exist
    // pH is absolutely required for any water analysis
    if (!row.containsKey(ExcelSchema.ph)) {
      errors.add('Missing critical parameter: pH');
    }

    // RULE 2: Data Types
    // Ensure numeric values are actually numbers
    row.forEach((key, value) {
      if (value is String && double.tryParse(value) == null) {
         // Allow date string if it parses?
         if (key == ExcelSchema.date) return;
         errors.add('Invalid number for $key: "$value"');
      }
    });

    return errors;
  }

  /// Validates the entire dataset.
  /// Throws [FormatException] if critical global errors exist (e.g. no data at all).
  static void validateDataset(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      throw const FormatException('No valid data found in the Excel file. Please check that your file contains a header row with parameters like "pH", "Alkalinity", etc.');
    }
    
    // Check if at least one row has a date
    bool hasDate = rows.any((r) => r.containsKey(ExcelSchema.date));
    if (!hasDate) {
      // Non-fatal? Maybe we default to file upload date.
      // For now, let's just warn or let the parser handle defaulting.
      print('Warning: No date column found in dataset.');
    }
  }
}
