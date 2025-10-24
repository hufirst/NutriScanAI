import 'package:flutter_test/flutter_test.dart';
import 'package:tandangenie/models/scan_result.dart';
import 'package:tandangenie/models/ratio_data.dart';

void main() {
  group('ScanResult', () {
    test('should create valid scan result', () {
      final scanResult = ScanResult(
        scanId: 'test-001',
        timestamp: DateTime.now(),
        carbRatio: 50,
        proteinRatio: 30,
        fatRatio: 20,
        imageUrl: '/path/to/image.jpg',
        validationStatus: 'passed',
      );

      expect(scanResult.scanId, 'test-001');
      expect(scanResult.carbRatio, 50);
      expect(scanResult.proteinRatio, 30);
      expect(scanResult.fatRatio, 20);
    });

    test('should throw assertion error if ratios dont sum to 100', () {
      expect(
        () => ScanResult(
          scanId: 'test-invalid',
          timestamp: DateTime.now(),
          carbRatio: 50,
          proteinRatio: 30,
          fatRatio: 30, // Sum = 110
          imageUrl: '/image.jpg',
          validationStatus: 'passed',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should serialize to map and deserialize back', () {
      final original = ScanResult(
        scanId: 'test-serialize',
        timestamp: DateTime(2025, 10, 19, 12, 0, 0),
        carbRatio: 40,
        proteinRatio: 35,
        fatRatio: 25,
        imageUrl: '/image.jpg',
        productName: 'Test Product',
        productNameConfidence: 0.95,
        validationStatus: 'passed',
      );

      final map = original.toMap();
      final deserialized = ScanResult.fromMap(map);

      expect(deserialized.scanId, original.scanId);
      expect(deserialized.carbRatio, original.carbRatio);
      expect(deserialized.proteinRatio, original.proteinRatio);
      expect(deserialized.fatRatio, original.fatRatio);
      expect(deserialized.productName, original.productName);
      expect(deserialized.productNameConfidence, original.productNameConfidence);
    });

    test('should format ratio with emojis', () {
      final scanResult = ScanResult(
        scanId: 'test-format',
        timestamp: DateTime.now(),
        carbRatio: 60,
        proteinRatio: 25,
        fatRatio: 15,
        imageUrl: '/image.jpg',
        validationStatus: 'passed',
      );

      expect(scanResult.formattedRatio, '🥖60 🍗25 🥑15');
    });

    test('should copy with modified fields', () {
      final original = ScanResult(
        scanId: 'test-copy',
        timestamp: DateTime.now(),
        carbRatio: 50,
        proteinRatio: 30,
        fatRatio: 20,
        imageUrl: '/image.jpg',
        validationStatus: 'passed',
      );

      final modified = original.copyWith(
        productName: 'Updated Name',
        productNameConfidence: 0.9,
      );

      expect(modified.scanId, original.scanId);
      expect(modified.carbRatio, original.carbRatio);
      expect(modified.productName, 'Updated Name');
      expect(modified.productNameConfidence, 0.9);
    });
  });

  group('RatioData', () {
    test('should calculate ratio from nutrition data', () {
      // Example: 30g carbs, 20g protein, 10g fat
      // Calories: 30*4 + 20*4 + 10*9 = 120 + 80 + 90 = 290 kcal
      // Ratios: 41%, 28%, 31%
      final ratio = RatioData.fromNutrition(
        carbohydratesG: 30.0,
        proteinG: 20.0,
        fatG: 10.0,
      );

      expect(ratio.carbRatio + ratio.proteinRatio + ratio.fatRatio, 100);
      expect(ratio.carbRatio, closeTo(41, 1));
      expect(ratio.proteinRatio, closeTo(28, 1));
      expect(ratio.fatRatio, closeTo(31, 1));
    });

    test('should format ratio correctly', () {
      final ratio = RatioData(carbRatio: 50, proteinRatio: 30, fatRatio: 20);
      expect(ratio.formatted, '🥖50 🍗30 🥑20');
      expect(ratio.chatDisplay, '50/30/20');
    });

    test('should throw error for invalid sum', () {
      expect(
        () => RatioData(carbRatio: 50, proteinRatio: 30, fatRatio: 30),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should support equality comparison', () {
      final ratio1 = RatioData(carbRatio: 50, proteinRatio: 30, fatRatio: 20);
      final ratio2 = RatioData(carbRatio: 50, proteinRatio: 30, fatRatio: 20);
      final ratio3 = RatioData(carbRatio: 40, proteinRatio: 30, fatRatio: 30);

      expect(ratio1 == ratio2, true);
      expect(ratio1 == ratio3, false);
    });
  });
}
