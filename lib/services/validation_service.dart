import '../utils/validators.dart';
import '../utils/constants.dart';
import '../models/validation_report.dart';
import 'package:uuid/uuid.dart';

/// 5-level validation pipeline for nutrition scan data
///
/// Implements progressive validation from required fields to confidence filtering:
/// Level 1: Required Fields
/// Level 2: Value Validation (ranges, types)
/// Level 3: Logical Consistency (ratio sum, calorie calculation)
/// Level 4: Anomaly Detection
/// Level 5: Confidence Filtering (threshold-based classification)
class ValidationService {
  final _uuid = const Uuid();

  /// Run complete 5-level validation pipeline
  ///
  /// Returns ValidationReport with results from all levels
  /// [scanId] The scan ID to associate with this validation
  /// [data] Complete Gemini API response data
  ValidationReport validate(String scanId, Map<String, dynamic> data) {
    // Level 1: Required Fields
    final level1Result = _validateLevel1(data);

    // Level 2: Value Validation
    final level2Result = _validateLevel2(data);

    // Level 3: Logical Consistency
    final level3Result = _validateLevel3(data);

    // Level 4: Anomaly Detection
    final level4Result = _validateLevel4(data);

    // Level 5: Confidence Filtering
    final level5Result = _validateLevel5(data);

    return ValidationReport(
      reportId: _uuid.v4(),
      scanId: scanId,
      createdAt: DateTime.now(),
      level1Pass: level1Result['pass'] as bool,
      level1MissingFields: level1Result['missing_fields'] as List<String>?,
      level2Warnings: level2Result['warnings'] as List<String>?,
      level3RatioSumValid: level3Result['ratio_sum_valid'] as bool?,
      level3CalorieDiffPercent:
          level3Result['calorie_diff_percent'] as double?,
      level4Anomalies: level4Result['anomalies'] as List<String>?,
      level5LowConfidenceCount:
          level5Result['low_confidence_count'] as int?,
      level5Details: level5Result['details'] as Map<String, dynamic>?,
    );
  }

  /// Level 1: Required Fields Validation
  ///
  /// Checks presence of mandatory fields: carbohydrates_g, protein_g, fat_g, ratio
  Map<String, dynamic> _validateLevel1(Map<String, dynamic> data) {
    final missingFields = Validators.getMissingRequiredFields(data);

    return {
      'pass': missingFields.isEmpty,
      'missing_fields': missingFields.isEmpty ? null : missingFields,
    };
  }

  /// Level 2: Value Validation
  ///
  /// Validates data types, ranges, and non-negative constraints
  Map<String, dynamic> _validateLevel2(Map<String, dynamic> data) {
    final warnings = <String>[];

    if (!data.containsKey('nutrition')) {
      return {'warnings': ['Missing nutrition section']};
    }

    final nutrition = data['nutrition'] as Map<String, dynamic>;

    // Check non-negative values
    final negativeErrors = Validators.checkNonNegativeValues(nutrition);
    warnings.addAll(negativeErrors);

    // Check calorie range
    if (nutrition.containsKey('calories') && nutrition['calories'] != null) {
      final calories = nutrition['calories'] as int;
      if (!Validators.areCaloriesValid(calories)) {
        warnings.add(
            'Calories out of range: $calories (expected ${AppConstants.minCalories}-${AppConstants.maxCalories})');
      }
    }

    // Check ratio values
    if (data.containsKey('ratio')) {
      final ratio = data['ratio'] as Map<String, dynamic>;
      ['carb_ratio', 'protein_ratio', 'fat_ratio'].forEach((field) {
        if (ratio.containsKey(field) && ratio[field] != null) {
          final value = ratio[field] as int;
          if (!Validators.isRatioValueValid(value)) {
            warnings.add('$field out of range: $value (expected 0-100)');
          }
        }
      });
    }

    // Check serving size format
    if (nutrition.containsKey('serving_size') &&
        nutrition['serving_size'] != null) {
      final servingSize = nutrition['serving_size'] as String;
      if (!_isValidServingSize(servingSize)) {
        warnings.add('Invalid serving size format: $servingSize');
      }
    }

    return {
      'warnings': warnings.isEmpty ? null : warnings,
    };
  }

  /// Level 3: Logical Consistency Validation
  ///
  /// Validates ratio sum = 100 and calorie calculation consistency
  Map<String, dynamic> _validateLevel3(Map<String, dynamic> data) {
    bool? ratioSumValid;
    double? calorieDiffPercent;

    // Check ratio sum
    if (data.containsKey('ratio')) {
      final ratio = data['ratio'] as Map<String, dynamic>;
      if (ratio.containsKey('carb_ratio') &&
          ratio.containsKey('protein_ratio') &&
          ratio.containsKey('fat_ratio')) {
        final carbRatio = ratio['carb_ratio'] as int;
        final proteinRatio = ratio['protein_ratio'] as int;
        final fatRatio = ratio['fat_ratio'] as int;

        ratioSumValid = Validators.isRatioSumValid(
          carbRatio,
          proteinRatio,
          fatRatio,
        );
      }
    }

    // Check calorie calculation consistency
    if (data.containsKey('nutrition')) {
      final nutrition = data['nutrition'] as Map<String, dynamic>;

      if (nutrition.containsKey('calories') &&
          nutrition.containsKey('carbohydrates_g') &&
          nutrition.containsKey('protein_g') &&
          nutrition.containsKey('fat_g') &&
          nutrition['calories'] != null &&
          nutrition['carbohydrates_g'] != null &&
          nutrition['protein_g'] != null &&
          nutrition['fat_g'] != null) {
        calorieDiffPercent = Validators.calculateCalorieDifference(
          reportedCalories: nutrition['calories'] as int,
          carbohydratesG: (nutrition['carbohydrates_g'] as num).toDouble(),
          proteinG: (nutrition['protein_g'] as num).toDouble(),
          fatG: (nutrition['fat_g'] as num).toDouble(),
        );
      }
    }

    return {
      'ratio_sum_valid': ratioSumValid,
      'calorie_diff_percent': calorieDiffPercent,
    };
  }

  /// Level 4: Anomaly Detection
  ///
  /// Detects suspicious patterns or inconsistencies
  Map<String, dynamic> _validateLevel4(Map<String, dynamic> data) {
    final anomalies = <String>[];

    if (!data.containsKey('nutrition')) {
      return {'anomalies': null};
    }

    final nutrition = data['nutrition'] as Map<String, dynamic>;

    // Anomaly 1: Extremely high fat ratio with low calories
    if (data.containsKey('ratio') && nutrition.containsKey('calories')) {
      final ratio = data['ratio'] as Map<String, dynamic>;
      if (ratio.containsKey('fat_ratio') && nutrition['calories'] != null) {
        final fatRatio = ratio['fat_ratio'] as int;
        final calories = nutrition['calories'] as int;

        if (fatRatio > 50 && calories < 150) {
          anomalies.add(
              'High fat ratio ($fatRatio%) with low calories (${calories}kcal) - unusual combination');
        }
      }
    }

    // Anomaly 2: Calorie calculation way off
    if (Validators.hasCalorieAnomaly(
      reportedCalories: nutrition['calories'] as int?,
      carbohydratesG: (nutrition['carbohydrates_g'] as num?)?.toDouble(),
      proteinG: (nutrition['protein_g'] as num?)?.toDouble(),
      fatG: (nutrition['fat_g'] as num?)?.toDouble(),
      threshold: 25.0, // 25% threshold for anomaly detection
    )) {
      anomalies.add(
          'Calorie calculation inconsistency exceeds 25% - possible OCR error');
    }

    // Anomaly 3: Suspiciously round numbers (all multiples of 5 or 10)
    if (nutrition.containsKey('carbohydrates_g') &&
        nutrition.containsKey('protein_g') &&
        nutrition.containsKey('fat_g')) {
      final carbs = (nutrition['carbohydrates_g'] as num?)?.toDouble();
      final protein = (nutrition['protein_g'] as num?)?.toDouble();
      final fat = (nutrition['fat_g'] as num?)?.toDouble();

      if (carbs != null &&
          protein != null &&
          fat != null &&
          _areAllRoundNumbers([carbs, protein, fat])) {
        anomalies.add(
            'All macronutrient values are round numbers - may indicate estimation rather than actual label');
      }
    }

    return {
      'anomalies': anomalies.isEmpty ? null : anomalies,
    };
  }

  /// Level 5: Confidence Filtering
  ///
  /// Filters classified data by confidence threshold (≥ 0.85)
  Map<String, dynamic> _validateLevel5(Map<String, dynamic> data) {
    int lowConfidenceCount = 0;
    final details = <String, dynamic>{};

    // Check nutrition confidence scores
    if (data.containsKey('nutrition')) {
      final nutrition = data['nutrition'] as Map<String, dynamic>;

      nutrition.forEach((key, value) {
        if (key.endsWith('_confidence') && value is num) {
          final fieldName = key.replaceAll('_confidence', '');
          final confidence = value.toDouble();

          if (!Validators.meetsConfidenceThreshold(confidence)) {
            lowConfidenceCount++;
            details[fieldName] = confidence;
          }
        }
      });
    }

    // Check classified data confidence scores
    if (data.containsKey('classified_data') && data['classified_data'] != null) {
      final classified = data['classified_data'] as Map<String, dynamic>;

      classified.forEach((key, value) {
        if (key.endsWith('_confidence') && value is num) {
          final fieldName = key.replaceAll('_confidence', '');
          final confidence = value.toDouble();

          if (!Validators.meetsConfidenceThreshold(confidence)) {
            lowConfidenceCount++;
            details[fieldName] = confidence;
          }
        }
      });
    }

    return {
      'low_confidence_count': lowConfidenceCount > 0 ? lowConfidenceCount : null,
      'details': details.isNotEmpty ? details : null,
    };
  }

  /// Determine overall validation status from report
  String getValidationStatus(ValidationReport report) {
    if (!report.level1Pass || report.hasCriticalFailure) {
      return AppConstants.validationStatusFailed;
    }

    if ((report.level2Warnings != null && report.level2Warnings!.isNotEmpty) ||
        (report.level4Anomalies != null && report.level4Anomalies!.isNotEmpty) ||
        (report.level5LowConfidenceCount != null &&
            report.level5LowConfidenceCount! > 3)) {
      return AppConstants.validationStatusWarning;
    }

    return AppConstants.validationStatusPassed;
  }

  /// Helper: Check if serving size has valid format (e.g., "100g", "250ml")
  bool _isValidServingSize(String servingSize) {
    // Simple regex: number followed by unit
    final pattern = RegExp(r'^\d+(\.\d+)?\s*(g|ml|mg|L|kg|회|개|인분)');
    return pattern.hasMatch(servingSize);
  }

  /// Helper: Check if all numbers are suspiciously round (multiples of 5 or 10)
  bool _areAllRoundNumbers(List<double> values) {
    return values.every((v) => v % 5 == 0);
  }
}
