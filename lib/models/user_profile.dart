/// User profile model for personalized health recommendations
///
/// Stores non-invasive personal information:
/// - Gender: For age/gender-specific nutrition guidelines
/// - Birth year/month: For age-based recommendations (no exact birthdate for privacy)
/// - Height/Weight: For BMI calculation and calorie recommendations
/// - Activity level: For daily calorie needs calculation
/// - Health goal: For personalized recommendations
/// - Dietary restrictions: For food alternatives
/// - Health conditions: For enhanced warnings (optional)
class UserProfile {
  // Basic information
  final String? gender; // 'male', 'female', 'other', or null
  final int? birthYear; // e.g., 1990
  final int? birthMonth; // 1-12

  // Physical measurements
  final double? heightCm; // Height in centimeters
  final double? weightKg; // Weight in kilograms

  // Lifestyle
  final String? activityLevel; // 'sedentary', 'light', 'moderate', 'active', 'very_active'
  final String? healthGoal; // 'lose', 'maintain', 'gain', 'muscle', 'health'

  // Dietary preferences and health
  final String? dietaryRestriction; // 'none', 'vegetarian', 'vegan', 'lactose', 'gluten'
  final String? healthCondition; // 'none', 'diabetes', 'hypertension', 'hyperlipidemia'

  const UserProfile({
    this.gender,
    this.birthYear,
    this.birthMonth,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.healthGoal,
    this.dietaryRestriction,
    this.healthCondition,
  });

  /// Check if user has completed basic profile setup
  bool get isBasicComplete =>
      gender != null &&
      birthYear != null &&
      birthMonth != null &&
      heightCm != null &&
      weightKg != null;

  /// Check if user has completed full profile setup
  bool get isFullComplete =>
      isBasicComplete &&
      activityLevel != null &&
      healthGoal != null;

  /// Calculate current age
  int? get age {
    if (birthYear == null) return null;
    final now = DateTime.now();
    int age = now.year - birthYear!;
    // Adjust if birthday hasn't occurred yet this year
    if (birthMonth != null && now.month < birthMonth!) {
      age--;
    }
    return age;
  }

  /// Get age group for recommendations
  /// WHO age groups: 0-5, 6-11, 12-18, 19-64, 65+
  String? get ageGroup {
    final currentAge = age;
    if (currentAge == null) return null;

    if (currentAge < 6) return 'child';
    if (currentAge < 12) return 'preteen';
    if (currentAge < 19) return 'teen';
    if (currentAge < 65) return 'adult';
    return 'senior';
  }

  /// Calculate BMI (Body Mass Index)
  /// BMI = weight(kg) / (height(m))^2
  double? get bmi {
    if (weightKg == null || heightCm == null) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  /// Get BMI category
  /// WHO classification: Underweight (<18.5), Normal (18.5-24.9), Overweight (25-29.9), Obese (>=30)
  String? get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return null;

    if (bmiValue < 18.5) return 'underweight';
    if (bmiValue < 25) return 'normal';
    if (bmiValue < 30) return 'overweight';
    return 'obese';
  }

  /// Calculate Basal Metabolic Rate (BMR) using Harris-Benedict equation
  /// Men: BMR = 88.362 + (13.397 × weight in kg) + (4.799 × height in cm) - (5.677 × age in years)
  /// Women: BMR = 447.593 + (9.247 × weight in kg) + (3.098 × height in cm) - (4.330 × age in years)
  double? get bmr {
    if (weightKg == null || heightCm == null || age == null || gender == null) {
      return null;
    }

    if (gender == 'male') {
      return 88.362 + (13.397 * weightKg!) + (4.799 * heightCm!) - (5.677 * age!);
    } else if (gender == 'female') {
      return 447.593 + (9.247 * weightKg!) + (3.098 * heightCm!) - (4.330 * age!);
    }

    // For 'other', use average of male/female formulas
    final maleBmr = 88.362 + (13.397 * weightKg!) + (4.799 * heightCm!) - (5.677 * age!);
    final femaleBmr = 447.593 + (9.247 * weightKg!) + (3.098 * heightCm!) - (4.330 * age!);
    return (maleBmr + femaleBmr) / 2;
  }

  /// Calculate Total Daily Energy Expenditure (TDEE) = BMR × activity factor
  /// Activity factors: sedentary (1.2), light (1.375), moderate (1.55), active (1.725), very_active (1.9)
  double? get tdee {
    final bmrValue = bmr;
    if (bmrValue == null || activityLevel == null) return null;

    final activityFactors = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };

    final factor = activityFactors[activityLevel] ?? 1.2;
    return bmrValue * factor;
  }

  /// Calculate target daily calories based on health goal
  /// lose: -500 kcal, maintain: 0, gain: +500 kcal, muscle: +300 kcal
  double? get targetCalories {
    final tdeeValue = tdee;
    if (tdeeValue == null || healthGoal == null) return tdeeValue;

    final adjustments = {
      'lose': -500.0,
      'maintain': 0.0,
      'gain': 500.0,
      'muscle': 300.0,
      'health': 0.0,
    };

    final adjustment = adjustments[healthGoal] ?? 0.0;
    return tdeeValue + adjustment;
  }

  /// Calculate recommended daily protein (g)
  /// General: 0.8g/kg, Muscle building: 1.6-2.2g/kg (use 1.8g/kg)
  double? get recommendedProteinG {
    if (weightKg == null) return null;

    if (healthGoal == 'muscle') {
      return weightKg! * 1.8; // Higher protein for muscle building
    }
    return weightKg! * 1.2; // Moderate protein for general health
  }

  /// Get recommended macronutrient ratios based on health goal
  /// Returns {carbs%, protein%, fat%}
  Map<String, int> get recommendedMacroRatios {
    // Default WHO recommendation: 50-30-20
    if (healthGoal == null) {
      return {'carbs': 50, 'protein': 30, 'fat': 20};
    }

    switch (healthGoal) {
      case 'lose': // Weight loss: Lower carbs, higher protein
        return {'carbs': 40, 'protein': 35, 'fat': 25};
      case 'maintain': // Maintain: Balanced WHO standard
        return {'carbs': 50, 'protein': 30, 'fat': 20};
      case 'gain': // Weight gain: Higher carbs for energy
        return {'carbs': 55, 'protein': 25, 'fat': 20};
      case 'muscle': // Muscle building: High protein
        return {'carbs': 40, 'protein': 40, 'fat': 20};
      case 'health': // General health: WHO standard
        return {'carbs': 50, 'protein': 30, 'fat': 20};
      default:
        return {'carbs': 50, 'protein': 30, 'fat': 20};
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel,
      'healthGoal': healthGoal,
      'dietaryRestriction': dietaryRestriction,
      'healthCondition': healthCondition,
    };
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String?,
      birthYear: json['birthYear'] as int?,
      birthMonth: json['birthMonth'] as int?,
      heightCm: json['heightCm'] as double?,
      weightKg: json['weightKg'] as double?,
      activityLevel: json['activityLevel'] as String?,
      healthGoal: json['healthGoal'] as String?,
      dietaryRestriction: json['dietaryRestriction'] as String?,
      healthCondition: json['healthCondition'] as String?,
    );
  }

  /// Create empty profile
  factory UserProfile.empty() {
    return const UserProfile();
  }

  /// Copy with updated fields
  UserProfile copyWith({
    String? gender,
    int? birthYear,
    int? birthMonth,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? healthGoal,
    String? dietaryRestriction,
    String? healthCondition,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      healthGoal: healthGoal ?? this.healthGoal,
      dietaryRestriction: dietaryRestriction ?? this.dietaryRestriction,
      healthCondition: healthCondition ?? this.healthCondition,
    );
  }

  @override
  String toString() {
    return 'UserProfile(gender: $gender, age: $age, bmi: ${bmi?.toStringAsFixed(1)}, '
        'tdee: ${tdee?.toStringAsFixed(0)} kcal, goal: $healthGoal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.gender == gender &&
        other.birthYear == birthYear &&
        other.birthMonth == birthMonth &&
        other.heightCm == heightCm &&
        other.weightKg == weightKg &&
        other.activityLevel == activityLevel &&
        other.healthGoal == healthGoal &&
        other.dietaryRestriction == dietaryRestriction &&
        other.healthCondition == healthCondition;
  }

  @override
  int get hashCode => Object.hash(
        gender,
        birthYear,
        birthMonth,
        heightCm,
        weightKg,
        activityLevel,
        healthGoal,
        dietaryRestriction,
        healthCondition,
      );
}
