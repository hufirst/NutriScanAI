import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Service for managing user profile data with SharedPreferences
///
/// Provides persistent storage for user profile information
/// including physical measurements, lifestyle, and health preferences.
class UserProfileService {
  static const String _profileKey = 'user_profile';
  late final SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the service (must be called before first use)
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugPrint('UserProfileService initialized');
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('UserProfileService not initialized. Call initialize() first.');
    }
  }

  /// Load user profile from storage
  ///
  /// Returns [UserProfile.empty()] if no profile exists
  Future<UserProfile> loadProfile() async {
    _ensureInitialized();

    final jsonString = _prefs.getString(_profileKey);
    if (jsonString == null || jsonString.isEmpty) {
      debugPrint('No user profile found, returning empty profile');
      return UserProfile.empty();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      debugPrint('Loaded user profile: $profile');
      return profile;
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return UserProfile.empty();
    }
  }

  /// Save user profile to storage
  ///
  /// Returns true if save was successful
  Future<bool> saveProfile(UserProfile profile) async {
    _ensureInitialized();

    try {
      final json = profile.toJson();
      final jsonString = jsonEncode(json);
      final success = await _prefs.setString(_profileKey, jsonString);

      if (success) {
        debugPrint('Saved user profile: $profile');
      } else {
        debugPrint('Failed to save user profile');
      }

      return success;
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      return false;
    }
  }

  /// Update specific profile fields
  ///
  /// Loads current profile, applies changes, and saves
  Future<bool> updateProfile({
    String? gender,
    int? birthYear,
    int? birthMonth,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? healthGoal,
    String? dietaryRestriction,
    String? healthCondition,
  }) async {
    final currentProfile = await loadProfile();
    final updatedProfile = currentProfile.copyWith(
      gender: gender,
      birthYear: birthYear,
      birthMonth: birthMonth,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      healthGoal: healthGoal,
      dietaryRestriction: dietaryRestriction,
      healthCondition: healthCondition,
    );

    return await saveProfile(updatedProfile);
  }

  /// Clear user profile from storage
  ///
  /// Returns true if clear was successful
  Future<bool> clearProfile() async {
    _ensureInitialized();

    try {
      final success = await _prefs.remove(_profileKey);
      if (success) {
        debugPrint('Cleared user profile');
      }
      return success;
    } catch (e) {
      debugPrint('Error clearing user profile: $e');
      return false;
    }
  }

  /// Check if user has any profile data saved
  Future<bool> hasProfile() async {
    _ensureInitialized();
    return _prefs.containsKey(_profileKey);
  }

  /// Check if user has completed basic profile setup
  Future<bool> hasBasicProfile() async {
    final profile = await loadProfile();
    return profile.isBasicComplete;
  }

  /// Check if user has completed full profile setup
  Future<bool> hasFullProfile() async {
    final profile = await loadProfile();
    return profile.isFullComplete;
  }

  /// Generate personalized prompt suffix for Gemini API
  ///
  /// Adds user-specific context for personalized health recommendations
  /// based on age, gender, BMI, activity level, and health conditions
  Future<String> generatePersonalizedPromptSuffix() async {
    final profile = await loadProfile();

    if (!profile.isBasicComplete) {
      // No profile data, return generic recommendations
      return '''

## Personalized Recommendations
Provide general health tips based on WHO guidelines (no user profile available).
''';
    }

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('## User Profile Context (for personalized recommendations)');
    buffer.writeln();

    // Basic demographics
    buffer.writeln('**Demographics:**');
    buffer.writeln('- Gender: ${profile.gender}');
    buffer.writeln('- Age: ${profile.age} years (${profile.ageGroup} age group)');
    buffer.writeln();

    // Physical measurements and BMI
    buffer.writeln('**Physical Measurements:**');
    buffer.writeln('- Height: ${profile.heightCm?.toStringAsFixed(1)} cm');
    buffer.writeln('- Weight: ${profile.weightKg?.toStringAsFixed(1)} kg');
    if (profile.bmi != null) {
      buffer.writeln('- BMI: ${profile.bmi!.toStringAsFixed(1)} (${profile.bmiCategory})');
    }
    buffer.writeln();

    // Calorie recommendations
    if (profile.bmr != null && profile.tdee != null) {
      buffer.writeln('**Daily Calorie Needs:**');
      buffer.writeln('- BMR (Basal Metabolic Rate): ${profile.bmr!.toStringAsFixed(0)} kcal');
      buffer.writeln('- TDEE (Total Daily Energy Expenditure): ${profile.tdee!.toStringAsFixed(0)} kcal');
      if (profile.activityLevel != null) {
        buffer.writeln('- Activity Level: ${profile.activityLevel}');
      }
      if (profile.targetCalories != null && profile.healthGoal != null) {
        buffer.writeln('- Target Calories (${profile.healthGoal} goal): ${profile.targetCalories!.toStringAsFixed(0)} kcal');
      }
      buffer.writeln();
    }

    // Protein recommendation
    if (profile.recommendedProteinG != null) {
      buffer.writeln('**Recommended Daily Protein:**');
      buffer.writeln('- ${profile.recommendedProteinG!.toStringAsFixed(0)}g per day');
      buffer.writeln();
    }

    // Health preferences
    if (profile.healthGoal != null || profile.dietaryRestriction != null || profile.healthCondition != null) {
      buffer.writeln('**Health Preferences:**');
      if (profile.healthGoal != null) {
        buffer.writeln('- Health Goal: ${profile.healthGoal}');
      }
      if (profile.dietaryRestriction != null && profile.dietaryRestriction != 'none') {
        buffer.writeln('- Dietary Restriction: ${profile.dietaryRestriction}');
      }
      if (profile.healthCondition != null && profile.healthCondition != 'none') {
        buffer.writeln('- Health Condition: ${profile.healthCondition}');

        // Add specific warnings for health conditions
        if (profile.healthCondition == 'diabetes') {
          buffer.writeln('  ⚠️ IMPORTANT: Flag high sugar/carb content prominently');
        } else if (profile.healthCondition == 'hypertension') {
          buffer.writeln('  ⚠️ IMPORTANT: Flag high sodium content prominently');
        } else if (profile.healthCondition == 'hyperlipidemia') {
          buffer.writeln('  ⚠️ IMPORTANT: Flag high saturated fat/cholesterol content prominently');
        }
      }
      buffer.writeln();
    }

    // Recommendation instructions
    buffer.writeln('**Recommendation Instructions:**');
    buffer.writeln('Based on the user profile above, provide personalized advice that:');
    buffer.writeln('1. Compares this food\'s calories to the user\'s target daily intake');
    buffer.writeln('2. Evaluates protein content against the user\'s recommended daily protein');
    buffer.writeln('3. Considers the user\'s health goal when suggesting alternatives');
    if (profile.dietaryRestriction != null && profile.dietaryRestriction != 'none') {
      buffer.writeln('4. Suggests alternatives compatible with ${profile.dietaryRestriction} diet');
    }
    if (profile.healthCondition != null && profile.healthCondition != 'none') {
      buffer.writeln('5. Provides enhanced warnings for ${profile.healthCondition}-specific concerns');
    }
    buffer.writeln();

    return buffer.toString();
  }
}
