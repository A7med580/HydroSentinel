/// Defines the canonical keys and their synonyms for the Excel parser.
class ExcelSchema {
  // Cooling Tower Parameters
  static const String ph = 'ph';
  static const String alkalinity = 'alkalinity';
  static const String conductivity = 'conductivity';
  static const String hardness = 'hardness';
  static const String chloride = 'chloride';
  static const String zinc = 'zinc';
  static const String iron = 'iron';
  static const String phosphate = 'phosphate';
  
  // RO Parameters
  static const String freeChlorine = 'free_chlorine';
  static const String silica = 'silica';
  static const String roConductivity = 'ro_conductivity';

  // Common
  static const String date = 'date';

  /// Maps canonical keys to a list of potential header synonyms.
  /// Evaluation is lower-case and stripped of whitespace.
  static final Map<String, List<String>> synonyms = {
    ph: ['ph', 'ph value', 'p.h.'],
    alkalinity: ['alkalinity', 'total alkalinity', 'm-alk', 'alk', 'm-alkalinity', 'total alk'],
    conductivity: ['conductivity', 'cond', 'ec', 'electrical conductivity', 'cond.'],
    hardness: ['hardness', 'total hardness', 'th', 't. hardness', 'calcium hardness'],
    chloride: ['chloride', 'cl', 'cl-', 'chlorides'],
    zinc: ['zinc', 'zn', 'zn2+'],
    iron: ['iron', 'fe', 'total iron', 'fe2+', 'fe3+'],
    phosphate: ['phosphate', 'po4', 'ortho phosphate', 'phosphates', 'ortho-po4'],
    date: ['date', 'report date', 'sampling date', 'date of sampling', 'time'],
    
    // RO
    freeChlorine: ['free chlorine', 'f-cl', 'f.cl', 'free cl2'],
    silica: ['silica', 'sio2', 'reactive silica'],
    roConductivity: ['ro conductivity', 'permeate conductivity', 'product conductivity'],
  };

  /// Returns the canonical key if the [header] matches any synonym.
  static String? match(String header) {
    final normalized = header.toLowerCase().trim();
    for (var entry in synonyms.entries) {
      if (entry.value.any((s) => normalized.contains(s))) {
        return entry.key;
      }
    }
    return null;
  }
}
