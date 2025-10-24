/// Carb-Protein-Fat ratio data (탄단지 비율)
///
/// Represents the core output of TanDanGenie: macronutrient ratios
class RatioData {
  /// Carbohydrate ratio (percentage, 0-100)
  final int carbRatio;

  /// Protein ratio (percentage, 0-100)
  final int proteinRatio;

  /// Fat ratio (percentage, 0-100)
  final int fatRatio;

  RatioData({
    required this.carbRatio,
    required this.proteinRatio,
    required this.fatRatio,
  }) {
    // Validate ratio sum
    final sum = carbRatio + proteinRatio + fatRatio;
    if (sum != 100) {
      throw ArgumentError(
        'Ratios must sum to 100, got $sum',
      );
    }

    // Validate ranges
    if (carbRatio < 0 || carbRatio > 100) {
      throw ArgumentError('carbRatio must be 0-100, got $carbRatio');
    }
    if (proteinRatio < 0 || proteinRatio > 100) {
      throw ArgumentError('proteinRatio must be 0-100, got $proteinRatio');
    }
    if (fatRatio < 0 || fatRatio > 100) {
      throw ArgumentError('fatRatio must be 0-100, got $fatRatio');
    }
  }

  /// Calculate ratios from nutrition data (grams)
  factory RatioData.fromNutrition({
    required double carbohydratesG,
    required double proteinG,
    required double fatG,
  }) {
    // Calculate calories per macronutrient
    // Carbs: 4 kcal/g, Protein: 4 kcal/g, Fat: 9 kcal/g
    final carbCalories = carbohydratesG * 4;
    final proteinCalories = proteinG * 4;
    final fatCalories = fatG * 9;

    final totalCalories = carbCalories + proteinCalories + fatCalories;

    if (totalCalories == 0) {
      // Default to equal distribution if no data
      return RatioData(carbRatio: 33, proteinRatio: 33, fatRatio: 34);
    }

    // Calculate percentages with smart rounding to ensure sum = 100
    final carbPercent = (carbCalories / totalCalories) * 100;
    final proteinPercent = (proteinCalories / totalCalories) * 100;
    final fatPercent = (fatCalories / totalCalories) * 100;

    // Floor all values first
    int carbRatio = carbPercent.floor();
    int proteinRatio = proteinPercent.floor();
    int fatRatio = fatPercent.floor();

    // Calculate how many we need to round up to reach 100
    int sum = carbRatio + proteinRatio + fatRatio;
    int remainder = 100 - sum;

    // Get fractional parts with their indices
    final fractions = [
      {'index': 0, 'fraction': carbPercent - carbPercent.floor()},
      {'index': 1, 'fraction': proteinPercent - proteinPercent.floor()},
      {'index': 2, 'fraction': fatPercent - fatPercent.floor()},
    ];

    // Sort by fraction (largest first)
    fractions.sort((a, b) => (b['fraction'] as double).compareTo(a['fraction'] as double));

    // Round up the top N values (where N = remainder)
    for (int i = 0; i < remainder; i++) {
      final index = fractions[i]['index'] as int;
      if (index == 0) carbRatio++;
      else if (index == 1) proteinRatio++;
      else fatRatio++;
    }

    return RatioData(
      carbRatio: carbRatio,
      proteinRatio: proteinRatio,
      fatRatio: fatRatio,
    );
  }

  /// Format for display: "🥖50 🍗30 🥑20"
  String get formatted {
    return '🥖$carbRatio 🍗$proteinRatio 🥑$fatRatio';
  }

  /// Format for chat display (compact)
  String get chatDisplay {
    return '$carbRatio/$proteinRatio/$fatRatio';
  }

  factory RatioData.fromJson(Map<String, dynamic> json) {
    return RatioData(
      carbRatio: json['carb_ratio'] as int,
      proteinRatio: json['protein_ratio'] as int,
      fatRatio: json['fat_ratio'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carb_ratio': carbRatio,
      'protein_ratio': proteinRatio,
      'fat_ratio': fatRatio,
    };
  }

  @override
  String toString() => formatted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RatioData &&
        other.carbRatio == carbRatio &&
        other.proteinRatio == proteinRatio &&
        other.fatRatio == fatRatio;
  }

  @override
  int get hashCode =>
      carbRatio.hashCode ^ proteinRatio.hashCode ^ fatRatio.hashCode;
}
