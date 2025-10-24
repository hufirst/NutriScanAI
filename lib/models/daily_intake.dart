/// Represents daily nutrition intake aggregated from multiple scans
///
/// This model aggregates all ScanResult data for a specific date
/// to provide daily totals for calories and macronutrients.
///
/// The model supports:
/// - Total calorie calculation from all scans
/// - Carb/Protein/Fat calorie breakdown
/// - Estimated vs confirmed data tracking
/// - Comparison with user's daily targets (TDEE)
class DailyIntake {
  // ============================================================================
  // Primary Key & Date
  // ============================================================================

  /// Date in YYYY-MM-DD format (e.g., "2025-10-23")
  final String date;

  // ============================================================================
  // Total Intake (Aggregated)
  // ============================================================================

  /// Total calories consumed today (sum of all scans)
  final int totalCalories;

  /// Total carbohydrate calories (carb_g * 4)
  final int carbCalories;

  /// Total protein calories (protein_g * 4)
  final int proteinCalories;

  /// Total fat calories (fat_g * 9)
  final int fatCalories;

  /// Total carbohydrates in grams
  final double totalCarbG;

  /// Total protein in grams
  final double totalProteinG;

  /// Total fat in grams
  final double totalFatG;

  // ============================================================================
  // Data Quality Flags
  // ============================================================================

  /// Whether any scan contains estimated data (not from nutrition label)
  final bool hasEstimatedData;

  /// Number of scans included in this daily total
  final int scanCount;

  // ============================================================================
  // Metadata
  // ============================================================================

  /// When this daily record was last updated
  final DateTime updatedAt;

  // ============================================================================
  // Constructor
  // ============================================================================

  const DailyIntake({
    required this.date,
    required this.totalCalories,
    required this.carbCalories,
    required this.proteinCalories,
    required this.fatCalories,
    required this.totalCarbG,
    required this.totalProteinG,
    required this.totalFatG,
    this.hasEstimatedData = false,
    required this.scanCount,
    required this.updatedAt,
  });

  // ============================================================================
  // Serialization
  // ============================================================================

  /// Convert to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'total_calories': totalCalories,
      'carb_calories': carbCalories,
      'protein_calories': proteinCalories,
      'fat_calories': fatCalories,
      'total_carb_g': totalCarbG,
      'total_protein_g': totalProteinG,
      'total_fat_g': totalFatG,
      'has_estimated_data': hasEstimatedData ? 1 : 0,
      'scan_count': scanCount,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Create from Map (SQLite row)
  factory DailyIntake.fromMap(Map<String, dynamic> map) {
    return DailyIntake(
      date: map['date'] as String,
      totalCalories: map['total_calories'] as int,
      carbCalories: map['carb_calories'] as int,
      proteinCalories: map['protein_calories'] as int,
      fatCalories: map['fat_calories'] as int,
      totalCarbG: map['total_carb_g'] as double,
      totalProteinG: map['total_protein_g'] as double,
      totalFatG: map['total_fat_g'] as double,
      hasEstimatedData: (map['has_estimated_data'] as int?) == 1,
      scanCount: map['scan_count'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as int) * 1000),
    );
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Create an empty daily intake for a date with no scans
  factory DailyIntake.empty(String date) {
    return DailyIntake(
      date: date,
      totalCalories: 0,
      carbCalories: 0,
      proteinCalories: 0,
      fatCalories: 0,
      totalCarbG: 0.0,
      totalProteinG: 0.0,
      totalFatG: 0.0,
      hasEstimatedData: false,
      scanCount: 0,
      updatedAt: DateTime.now(),
    );
  }

  /// Calculate carb:protein:fat ratio as percentages
  Map<String, int> get macroRatios {
    if (totalCalories == 0) {
      return {'carb': 0, 'protein': 0, 'fat': 0};
    }

    final carbRatio = ((carbCalories / totalCalories) * 100).round();
    final proteinRatio = ((proteinCalories / totalCalories) * 100).round();
    final fatRatio = ((fatCalories / totalCalories) * 100).round();

    // Ensure sum is 100% by adjusting the largest value
    int sum = carbRatio + proteinRatio + fatRatio;
    if (sum != 100) {
      final diff = 100 - sum;
      // Adjust the largest ratio
      if (carbRatio >= proteinRatio && carbRatio >= fatRatio) {
        return {
          'carb': carbRatio + diff,
          'protein': proteinRatio,
          'fat': fatRatio
        };
      } else if (proteinRatio >= fatRatio) {
        return {
          'carb': carbRatio,
          'protein': proteinRatio + diff,
          'fat': fatRatio
        };
      } else {
        return {
          'carb': carbRatio,
          'protein': proteinRatio,
          'fat': fatRatio + diff
        };
      }
    }

    return {'carb': carbRatio, 'protein': proteinRatio, 'fat': fatRatio};
  }

  /// Format ratio for display: "🥖50 🍗30 🥑20"
  String get formattedRatio {
    final ratios = macroRatios;
    return '🥖${ratios['carb']} 🍗${ratios['protein']} 🥑${ratios['fat']}';
  }

  /// Calculate completion percentage against target calories
  int completionPercentage(int targetCalories) {
    if (targetCalories == 0) return 0;
    return ((totalCalories / targetCalories) * 100).round().clamp(0, 999);
  }

  /// Create a copy with modified fields
  DailyIntake copyWith({
    String? date,
    int? totalCalories,
    int? carbCalories,
    int? proteinCalories,
    int? fatCalories,
    double? totalCarbG,
    double? totalProteinG,
    double? totalFatG,
    bool? hasEstimatedData,
    int? scanCount,
    DateTime? updatedAt,
  }) {
    return DailyIntake(
      date: date ?? this.date,
      totalCalories: totalCalories ?? this.totalCalories,
      carbCalories: carbCalories ?? this.carbCalories,
      proteinCalories: proteinCalories ?? this.proteinCalories,
      fatCalories: fatCalories ?? this.fatCalories,
      totalCarbG: totalCarbG ?? this.totalCarbG,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      hasEstimatedData: hasEstimatedData ?? this.hasEstimatedData,
      scanCount: scanCount ?? this.scanCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DailyIntake(date: $date, totalCalories: $totalCalories, '
        'ratios: ${macroRatios}, scanCount: $scanCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyIntake && other.date == date;
  }

  @override
  int get hashCode => date.hashCode;
}
