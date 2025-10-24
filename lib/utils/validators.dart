import '../utils/constants.dart';

/// Validation utility functions for nutrition data
///
/// Provides helpers for ratio sum validation, calorie calculation,
/// and range checks used throughout the validation pipeline.
class Validators {
  Validators._(); // Prevent instantiation

  /// Validate that ratio sum equals 100 within tolerance
  ///
  /// Returns true if sum is within acceptable range (100 ± tolerance)
  static bool isRatioSumValid(int carbRatio, int proteinRatio, int fatRatio) {
    final sum = carbRatio + proteinRatio + fatRatio;
    return (sum - 100).abs() <= AppConstants.ratioSumTolerance;
  }

  /// Calculate expected calories from macronutrient grams
  ///
  /// Formula: (carbs + protein) * 4 + fat * 9
  static int calculateCaloriesFromMacros({
    required double carbohydratesG,
    required double proteinG,
    required double fatG,
  }) {
    return ((carbohydratesG + proteinG) * 4 + fatG * 9).round();
  }

  /// Calculate percentage difference between reported and calculated calories
  ///
  /// Returns percentage difference (0.0 to 100.0+)
  static double calculateCalorieDifference({
    required int reportedCalories,
    required double carbohydratesG,
    required double proteinG,
    required double fatG,
  }) {
    final calculatedCalories = calculateCaloriesFromMacros(
      carbohydratesG: carbohydratesG,
      proteinG: proteinG,
      fatG: fatG,
    );

    if (calculatedCalories == 0) return 100.0;

    return ((reportedCalories - calculatedCalories).abs() /
            calculatedCalories *
            100)
        .toDouble();
  }

  /// Validate that a value is within acceptable range
  static bool isInRange(num value, num min, num max) {
    return value >= min && value <= max;
  }

  /// Validate calories are within reasonable range
  static bool areCaloriesValid(int calories) {
    return isInRange(
        calories, AppConstants.minCalories, AppConstants.maxCalories);
  }

  /// Validate ratio values are within 0-100
  static bool isRatioValueValid(int ratio) {
    return isInRange(
        ratio, AppConstants.minRatioValue, AppConstants.maxRatioValue);
  }

  /// Check if confidence score meets threshold
  static bool meetsConfidenceThreshold(double? confidence) {
    if (confidence == null) return false;
    return confidence >= AppConstants.confidenceThreshold;
  }

  /// Detect anomaly: ratio sum close to 100 but calories way off
  static bool hasCalorieAnomaly({
    required int? reportedCalories,
    required double? carbohydratesG,
    required double? proteinG,
    required double? fatG,
    double threshold = 20.0, // 20% difference threshold
  }) {
    if (reportedCalories == null ||
        carbohydratesG == null ||
        proteinG == null ||
        fatG == null) {
      return false;
    }

    final diff = calculateCalorieDifference(
      reportedCalories: reportedCalories,
      carbohydratesG: carbohydratesG,
      proteinG: proteinG,
      fatG: fatG,
    );

    return diff > threshold;
  }

  /// Check if all required nutrition fields are non-null
  static bool hasRequiredNutritionFields(Map<String, dynamic> nutrition) {
    final required = ['carbohydrates_g', 'protein_g', 'fat_g'];
    return required.every((field) => nutrition[field] != null);
  }

  /// Get list of missing required fields
  static List<String> getMissingRequiredFields(Map<String, dynamic> data) {
    final missing = <String>[];

    // Check nutrition section
    if (!data.containsKey('nutrition')) {
      missing.add('nutrition');
      return missing; // Can't check further without nutrition section
    }

    final nutrition = data['nutrition'] as Map<String, dynamic>;
    final requiredNutrients = ['carbohydrates_g', 'protein_g', 'fat_g'];

    for (final field in requiredNutrients) {
      if (!nutrition.containsKey(field) || nutrition[field] == null) {
        missing.add('nutrition.$field');
      }
    }

    // Check ratio section
    if (!data.containsKey('ratio')) {
      missing.add('ratio');
    } else {
      final ratio = data['ratio'] as Map<String, dynamic>;
      final requiredRatios = ['carb_ratio', 'protein_ratio', 'fat_ratio'];

      for (final field in requiredRatios) {
        if (!ratio.containsKey(field) || ratio[field] == null) {
          missing.add('ratio.$field');
        }
      }
    }

    return missing;
  }

  /// Validate all values are non-negative
  static List<String> checkNonNegativeValues(Map<String, dynamic> nutrition) {
    final errors = <String>[];

    nutrition.forEach((key, value) {
      if (key.endsWith('_confidence')) return; // Skip confidence scores
      if (value is num && value < 0) {
        errors.add('$key is negative: $value');
      }
    });

    return errors;
  }
}
