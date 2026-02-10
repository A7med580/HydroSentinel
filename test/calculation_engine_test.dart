import 'package:flutter_test/flutter_test.dart';
import 'package:hydrosentinel/services/calculation_engine.dart';
import 'package:hydrosentinel/models/chemistry_models.dart';
import 'package:hydrosentinel/models/assessment_models.dart';

void main() {
  group('CalculationEngine - Indices', () {
    test('LSI Calculation matches reference values', () {
      // Test Case 1: Balanced Water
      // pH: 7.5, Alk: 100, Hard: 100, Cond: 1000 (TDS ~670), Temp: 35
      final data = CoolingTowerData(
        ph: WaterParameter(name: 'pH', value: 7.5, unit: 'pH'),
        alkalinity: WaterParameter(name: 'Alk', value: 100, unit: 'ppm'),
        totalHardness: WaterParameter(name: 'Hard', value: 100, unit: 'ppm'),
        conductivity: WaterParameter(name: 'Cond', value: 1000, unit: 'µS/cm'),
        chloride: WaterParameter(name: 'Cl', value: 50, unit: 'ppm'),
        zinc: WaterParameter(name: 'Zn', value: 1.0, unit: 'ppm'),
        iron: WaterParameter(name: 'Fe', value: 0.1, unit: 'ppm'),
        phosphates: WaterParameter(name: 'PO4', value: 5.0, unit: 'ppm'),
        temperature: WaterParameter(name: 'Temp', value: 35, unit: '°C'),
        timestamp: DateTime.now(),
      );

      final indices = CalculationEngine.calculateIndices(data);
      
      // Manual Check:
      // TDS = 670, A ~ 0.18, B ~ 1.76, C ~ 1.6, D = 2.0
      // pHs ~ (9.3 + 0.18 + 1.76) - (1.6 + 2.0) = 11.24 - 3.6 = 7.64
      // LSI = 7.5 - 7.78 = -0.28
      // Allow minor float differences
      expect(indices.lsi, closeTo(-0.28, 0.1));
    });

    test('Stiff-Davis returns null for low TDS', () {
      final data = CoolingTowerData(
        ph: WaterParameter(name: 'pH', value: 7.5, unit: 'pH'),
        alkalinity: WaterParameter(name: 'Alk', value: 100, unit: 'ppm'),
        totalHardness: WaterParameter(name: 'Hard', value: 100, unit: 'ppm'),
        conductivity: WaterParameter(name: 'Cond', value: 100, unit: 'µS/cm'), // Low TDS ~67
        chloride: WaterParameter(name: 'Cl', value: 50, unit: 'ppm'),
        zinc: WaterParameter(name: 'Zn', value: 1.0, unit: 'ppm'),
        iron: WaterParameter(name: 'Fe', value: 0.1, unit: 'ppm'),
        phosphates: WaterParameter(name: 'PO4', value: 5.0, unit: 'ppm'),
        temperature: WaterParameter(name: 'Temp', value: 35, unit: '°C'),
        timestamp: DateTime.now(),
      );

      final indices = CalculationEngine.calculateIndices(data);
      expect(indices.stiffDavis, isNull);
    });
    
    test('PSI NaN Guard works for 0 Alkalinity', () {
      final data = CoolingTowerData(
        ph: WaterParameter(name: 'pH', value: 7.5, unit: 'pH'),
        alkalinity: WaterParameter(name: 'Alk', value: 0, unit: 'ppm'), // Testing edge case
        totalHardness: WaterParameter(name: 'Hard', value: 100, unit: 'ppm'),
        conductivity: WaterParameter(name: 'Cond', value: 1000, unit: 'µS/cm'),
        chloride: WaterParameter(name: 'Cl', value: 50, unit: 'ppm'),
        zinc: WaterParameter(name: 'Zn', value: 1.0, unit: 'ppm'),
        iron: WaterParameter(name: 'Fe', value: 0.1, unit: 'ppm'),
        phosphates: WaterParameter(name: 'PO4', value: 5.0, unit: 'ppm'),
        temperature: WaterParameter(name: 'Temp', value: 35, unit: '°C'),
        timestamp: DateTime.now(),
      );

      final indices = CalculationEngine.calculateIndices(data);
      expect(indices.psi, isNot(isNaN));
      expect(indices.lsi, isNot(isNaN));
    });
  });

  group('CalculationEngine - Risk Assessment', () {
    test('LSI > 0.5 increases scaling score', () {
        // High scaling: LSI > 2.0 (pH 8.5, Hard 400, Alk 400)
        final data = CoolingTowerData(
          ph: WaterParameter(name: 'pH', value: 8.5, unit: 'pH'),
          alkalinity: WaterParameter(name: 'Alk', value: 400, unit: 'ppm'),
          totalHardness: WaterParameter(name: 'Hard', value: 400, unit: 'ppm'),
          conductivity: WaterParameter(name: 'Cond', value: 2000, unit: 'µS/cm'),
          chloride: WaterParameter(name: 'Cl', value: 50, unit: 'ppm'),
          zinc: WaterParameter(name: 'Zn', value: 1.0, unit: 'ppm'),
          iron: WaterParameter(name: 'Fe', value: 0.1, unit: 'ppm'),
          phosphates: WaterParameter(name: 'PO4', value: 5.0, unit: 'ppm'),
          temperature: WaterParameter(name: 'Temp', value: 40, unit: '°C'),
          timestamp: DateTime.now(),
        );
        
        final indices = CalculationEngine.calculateIndices(data);
        final risk = CalculationEngine.assessRisk(indices, data);
        
        expect(risk.scalingScore, greaterThanOrEqualTo(80)); // Should be excessive scaling risk
        expect(risk.scalingRisk, equals(RiskLevel.critical));
    });

    test('High Chloride increases corrosion score', () {
        final data = CoolingTowerData(
          ph: WaterParameter(name: 'pH', value: 7.0, unit: 'pH'),
          alkalinity: WaterParameter(name: 'Alk', value: 100, unit: 'ppm'),
          totalHardness: WaterParameter(name: 'Hard', value: 100, unit: 'ppm'),
          conductivity: WaterParameter(name: 'Cond', value: 2000, unit: 'µS/cm'),
          chloride: WaterParameter(name: 'Cl', value: 1000, unit: 'ppm'), // Very high
          zinc: WaterParameter(name: 'Zn', value: 0.1, unit: 'ppm'), // Low inhibitor
          iron: WaterParameter(name: 'Fe', value: 0.1, unit: 'ppm'),
          phosphates: WaterParameter(name: 'PO4', value: 5.0, unit: 'ppm'),
          timestamp: DateTime.now(),
        );

        final indices = CalculationEngine.calculateIndices(data);
        final risk = CalculationEngine.assessRisk(indices, data);

        expect(risk.corrosionScore, greaterThan(50));
    });
  });

  group('CalculationEngine - Bounds Validation', () {
    test('Validates pH bounds', () {
      expect(CalculationEngine.validateParameterBounds('pH', 7.0), isNull);
      expect(CalculationEngine.validateParameterBounds('pH', 15.0), contains('out of range'));
      expect(CalculationEngine.validateParameterBounds('pH', -1.0), contains('out of range'));
    });

    test('Validates Temperature bounds', () {
       expect(CalculationEngine.validateParameterBounds('Temp', 40.0), isNull);
       expect(CalculationEngine.validateParameterBounds('Temp', 80.0), contains('out of range'));
    });
  });
}
