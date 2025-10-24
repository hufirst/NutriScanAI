import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/daily_intake.dart';
import '../models/scan_result.dart';
import 'storage_service.dart';

/// Service for managing daily nutrition intake aggregation
///
/// Calculates and stores daily totals from scan results:
/// - Aggregates all scans for a specific date
/// - Calculates total calories and macronutrient breakdown
/// - Tracks estimated data flags
/// - Provides statistics and comparison with goals
class DailyIntakeService {
  final StorageService _storage = StorageService();

  // ============================================================================
  // Core Operations
  // ============================================================================

  /// Get daily intake for a specific date (YYYY-MM-DD format)
  /// Returns empty DailyIntake if no data exists for that date
  Future<DailyIntake> getDailyIntake(String date) async {
    final db = await _storage.database;
    final results = await db.query(
      'daily_intake',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (results.isEmpty) {
      return DailyIntake.empty(date);
    }

    return DailyIntake.fromMap(results.first);
  }

  /// Recalculate and update daily intake for a specific date
  /// Aggregates all ScanResult data for that date
  Future<DailyIntake> recalculateDailyIntake(String date) async {
    // Get all scan results for the date
    final scans = await _getScanResultsForDate(date);

    if (scans.isEmpty) {
      // No scans for this date, delete existing record if any
      await _deleteDailyIntake(date);
      return DailyIntake.empty(date);
    }

    // Aggregate nutrition data
    int totalCalories = 0;
    double totalCarbG = 0.0;
    double totalProteinG = 0.0;
    double totalFatG = 0.0;
    bool hasEstimated = false;

    for (final scan in scans) {
      // Only include scans with valid nutrition data
      if (scan.calories != null &&
          scan.carbohydratesG != null &&
          scan.proteinG != null &&
          scan.fatG != null) {
        totalCalories += scan.calories!;
        totalCarbG += scan.carbohydratesG!;
        totalProteinG += scan.proteinG!;
        totalFatG += scan.fatG!;

        // Check if this scan has low confidence (estimated data)
        if ((scan.caloriesConfidence ?? 1.0) < 0.85 ||
            (scan.carbohydratesConfidence ?? 1.0) < 0.85 ||
            (scan.proteinConfidence ?? 1.0) < 0.85 ||
            (scan.fatConfidence ?? 1.0) < 0.85) {
          hasEstimated = true;
        }
      }
    }

    // Calculate calorie breakdown (carb/protein: 4 kcal/g, fat: 9 kcal/g)
    final carbCalories = (totalCarbG * 4).round();
    final proteinCalories = (totalProteinG * 4).round();
    final fatCalories = (totalFatG * 9).round();

    // Create DailyIntake object
    final dailyIntake = DailyIntake(
      date: date,
      totalCalories: totalCalories,
      carbCalories: carbCalories,
      proteinCalories: proteinCalories,
      fatCalories: fatCalories,
      totalCarbG: totalCarbG,
      totalProteinG: totalProteinG,
      totalFatG: totalFatG,
      hasEstimatedData: hasEstimated,
      scanCount: scans.length,
      updatedAt: DateTime.now(),
    );

    // Save to database
    await _upsertDailyIntake(dailyIntake);

    debugPrint('✅ Recalculated daily intake for $date: '
        '${totalCalories} kcal from ${scans.length} scans');

    return dailyIntake;
  }

  /// Get daily intake for today
  Future<DailyIntake> getTodayIntake() async {
    final today = _formatDate(DateTime.now());
    return await getDailyIntake(today);
  }

  /// Recalculate today's intake
  Future<DailyIntake> recalculateTodayIntake() async {
    final today = _formatDate(DateTime.now());
    return await recalculateDailyIntake(today);
  }

  // ============================================================================
  // Statistics & Comparison
  // ============================================================================

  /// Get daily intake for a date range
  Future<List<DailyIntake>> getDailyIntakeRange(
      DateTime startDate, DateTime endDate) async {
    final db = await _storage.database;
    final results = await db.query(
      'daily_intake',
      where: 'date >= ? AND date <= ?',
      whereArgs: [_formatDate(startDate), _formatDate(endDate)],
      orderBy: 'date DESC',
    );

    return results.map((map) => DailyIntake.fromMap(map)).toList();
  }

  /// Get recent daily intakes (last N days with data)
  Future<List<DailyIntake>> getRecentDailyIntakes({int limit = 7}) async {
    final db = await _storage.database;
    final results = await db.query(
      'daily_intake',
      orderBy: 'date DESC',
      limit: limit,
    );

    return results.map((map) => DailyIntake.fromMap(map)).toList();
  }

  /// Calculate average daily intake over a period
  Future<Map<String, double>> getAverageIntake(
      DateTime startDate, DateTime endDate) async {
    final intakes = await getDailyIntakeRange(startDate, endDate);

    if (intakes.isEmpty) {
      return {
        'avgCalories': 0.0,
        'avgCarbG': 0.0,
        'avgProteinG': 0.0,
        'avgFatG': 0.0,
      };
    }

    double totalCalories = 0.0;
    double totalCarbG = 0.0;
    double totalProteinG = 0.0;
    double totalFatG = 0.0;

    for (final intake in intakes) {
      totalCalories += intake.totalCalories;
      totalCarbG += intake.totalCarbG;
      totalProteinG += intake.totalProteinG;
      totalFatG += intake.totalFatG;
    }

    final count = intakes.length;
    return {
      'avgCalories': totalCalories / count,
      'avgCarbG': totalCarbG / count,
      'avgProteinG': totalProteinG / count,
      'avgFatG': totalFatG / count,
    };
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Get all scan results for a specific date
  Future<List<ScanResult>> _getScanResultsForDate(String date) async {
    final db = await _storage.database;

    // Parse date to get start and end timestamps
    final dateTime = DateTime.parse(date);
    final startOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0);
    final endOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);

    final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;

    final results = await db.query(
      'scan_results',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => ScanResult.fromMap(map)).toList();
  }

  /// Insert or update daily intake record
  Future<void> _upsertDailyIntake(DailyIntake dailyIntake) async {
    final db = await _storage.database;
    await db.insert(
      'daily_intake',
      dailyIntake.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete daily intake record for a date
  Future<void> _deleteDailyIntake(String date) async {
    final db = await _storage.database;
    await db.delete(
      'daily_intake',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// Format DateTime to YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // Public Utilities
  // ============================================================================

  /// Get formatted date string for today
  String getTodayDate() {
    return _formatDate(DateTime.now());
  }

  /// Parse date string to DateTime
  DateTime parseDate(String dateString) {
    return DateTime.parse(dateString);
  }

  /// Check if a date has any scan data
  Future<bool> hasDataForDate(String date) async {
    final scans = await _getScanResultsForDate(date);
    return scans.isNotEmpty;
  }

  /// Delete all daily intake records (for testing/reset)
  Future<void> deleteAllDailyIntakes() async {
    final db = await _storage.database;
    await db.delete('daily_intake');
    debugPrint('🗑️ Deleted all daily intake records');
  }
}
