import 'dart:convert';

/// Validation report for 5-level validation pipeline
///
/// Stores detailed validation results for failed/warning scans
class ValidationReport {
  final String reportId;
  final String scanId;
  final DateTime createdAt;

  // Level 1: Required Fields
  final bool level1Pass;
  final List<String>? level1MissingFields;

  // Level 2: Value Validation
  final List<String>? level2Warnings;

  // Level 3: Logical Consistency
  final bool? level3RatioSumValid;
  final double? level3CalorieDiffPercent;

  // Level 4: Anomaly Detection
  final List<String>? level4Anomalies;

  // Level 5: Confidence Filtering
  final int? level5LowConfidenceCount;
  final Map<String, dynamic>? level5Details;

  ValidationReport({
    required this.reportId,
    required this.scanId,
    required this.createdAt,
    required this.level1Pass,
    this.level1MissingFields,
    this.level2Warnings,
    this.level3RatioSumValid,
    this.level3CalorieDiffPercent,
    this.level4Anomalies,
    this.level5LowConfidenceCount,
    this.level5Details,
  });

  /// Overall validation status
  String get overallStatus {
    if (!level1Pass) return 'failed';
    if (level2Warnings != null && level2Warnings!.isNotEmpty) return 'warning';
    if (level4Anomalies != null && level4Anomalies!.isNotEmpty) return 'warning';
    if (level5LowConfidenceCount != null && level5LowConfidenceCount! > 0) {
      return 'warning';
    }
    return 'passed';
  }

  /// Check if report indicates a critical failure
  bool get hasCriticalFailure {
    return !level1Pass || (level3RatioSumValid != null && !level3RatioSumValid!);
  }

  Map<String, dynamic> toMap() {
    return {
      'report_id': reportId,
      'scan_id': scanId,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'level1_pass': level1Pass ? 1 : 0,
      'level1_missing_fields': level1MissingFields != null
          ? jsonEncode(level1MissingFields)
          : null,
      'level2_warnings':
          level2Warnings != null ? jsonEncode(level2Warnings) : null,
      'level3_ratio_sum_valid':
          level3RatioSumValid != null ? (level3RatioSumValid! ? 1 : 0) : null,
      'level3_calorie_diff_percent': level3CalorieDiffPercent,
      'level4_anomalies':
          level4Anomalies != null ? jsonEncode(level4Anomalies) : null,
      'level5_low_confidence_count': level5LowConfidenceCount,
      'level5_details':
          level5Details != null ? jsonEncode(level5Details) : null,
    };
  }

  factory ValidationReport.fromMap(Map<String, dynamic> map) {
    return ValidationReport(
      reportId: map['report_id'] as String,
      scanId: map['scan_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as int) * 1000),
      level1Pass: (map['level1_pass'] as int) == 1,
      level1MissingFields: map['level1_missing_fields'] != null
          ? List<String>.from(
              jsonDecode(map['level1_missing_fields'] as String) as List)
          : null,
      level2Warnings: map['level2_warnings'] != null
          ? List<String>.from(
              jsonDecode(map['level2_warnings'] as String) as List)
          : null,
      level3RatioSumValid: map['level3_ratio_sum_valid'] != null
          ? (map['level3_ratio_sum_valid'] as int) == 1
          : null,
      level3CalorieDiffPercent: map['level3_calorie_diff_percent'] as double?,
      level4Anomalies: map['level4_anomalies'] != null
          ? List<String>.from(
              jsonDecode(map['level4_anomalies'] as String) as List)
          : null,
      level5LowConfidenceCount: map['level5_low_confidence_count'] as int?,
      level5Details: map['level5_details'] != null
          ? jsonDecode(map['level5_details'] as String) as Map<String, dynamic>
          : null,
    );
  }

  @override
  String toString() {
    return 'ValidationReport(reportId: $reportId, scanId: $scanId, '
        'status: $overallStatus, level1Pass: $level1Pass)';
  }
}
