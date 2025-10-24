/// Nutrition data extracted from label
///
/// Separates Raw OCR output from Classified nutrition facts
class NutritionData {
  // Classified Data (confidence ≥ 0.85)
  final String? servingSize;
  final int? calories;
  final double? carbohydratesG;
  final double? proteinG;
  final double? fatG;
  final int? sodiumMg;
  final double? sugarsG;
  final double? saturatedFatG;
  final double? transFatG;
  final int? cholesterolMg;
  final double? dietaryFiberG;

  // Confidence scores
  final Map<String, double> confidenceScores;

  // Raw data (always preserved)
  final Map<String, dynamic> rawData;

  NutritionData({
    this.servingSize,
    this.calories,
    this.carbohydratesG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.sugarsG,
    this.saturatedFatG,
    this.transFatG,
    this.cholesterolMg,
    this.dietaryFiberG,
    required this.confidenceScores,
    required this.rawData,
  });

  /// Check if all required macros are present
  bool get hasRequiredMacros {
    return carbohydratesG != null && proteinG != null && fatG != null;
  }

  /// Check if calories are provided
  bool get hasCalories => calories != null;

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      servingSize: json['serving_size'] as String?,
      calories: _parseIntSafely(json['calories']),
      carbohydratesG: json['carbohydrates_g'] as double?,
      proteinG: json['protein_g'] as double?,
      fatG: json['fat_g'] as double?,
      sodiumMg: _parseIntSafely(json['sodium_mg']),
      sugarsG: json['sugars_g'] as double?,
      saturatedFatG: json['saturated_fat_g'] as double?,
      transFatG: json['trans_fat_g'] as double?,
      cholesterolMg: _parseIntSafely(json['cholesterol_mg']),
      dietaryFiberG: json['dietary_fiber_g'] as double?,
      confidenceScores:
          Map<String, double>.from(json['confidence_scores'] as Map),
      rawData: json['raw_data'] as Map<String, dynamic>,
    );
  }

  /// Safely parse integer from dynamic value (handles String, int, double)
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'serving_size': servingSize,
      'calories': calories,
      'carbohydrates_g': carbohydratesG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'sodium_mg': sodiumMg,
      'sugars_g': sugarsG,
      'saturated_fat_g': saturatedFatG,
      'trans_fat_g': transFatG,
      'cholesterol_mg': cholesterolMg,
      'dietary_fiber_g': dietaryFiberG,
      'confidence_scores': confidenceScores,
      'raw_data': rawData,
    };
  }
}
