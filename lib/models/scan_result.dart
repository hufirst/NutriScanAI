import 'dart:convert';

/// Represents a complete nutrition label scan result
///
/// This model follows the Raw/Classified data separation strategy:
/// - Certain Data: carb_ratio, protein_ratio, fat_ratio (always present)
/// - Classified Data: product info and nutrition facts (if confidence ≥ 0.85)
/// - Raw Data: OCR full text and JSON (always preserved)
class ScanResult {
  // ============================================================================
  // Primary Key & Timestamp
  // ============================================================================

  final String scanId;
  final DateTime timestamp;

  // ============================================================================
  // Certain Data (100% reliable)
  // ============================================================================

  /// Carbohydrate ratio (percentage, 0-100)
  final int carbRatio;

  /// Protein ratio (percentage, 0-100)
  final int proteinRatio;

  /// Fat ratio (percentage, 0-100)
  final int fatRatio;

  /// Local file path to the scanned image
  final String imageUrl;

  // ============================================================================
  // Classified Data (confidence ≥ 0.85)
  // ============================================================================

  /// Product name (null if confidence < 0.85)
  final String? productName;
  final double? productNameConfidence;

  /// Manufacturer/brand name
  final String? manufacturer;
  final double? manufacturerConfidence;

  /// Barcode number
  final String? barcode;
  final double? barcodeConfidence;
  final bool barcodeVerified;

  /// Food category (e.g., "스낵", "음료", "유제품")
  final String? foodCategory;
  final double? categoryConfidence;

  // ============================================================================
  // Nutrition Facts (Classified)
  // ============================================================================

  /// Serving size (e.g., "1회 제공량(30g)")
  final String? servingSize;
  final double? servingSizeConfidence;

  /// Calories per serving (kcal)
  final int? calories;
  final double? caloriesConfidence;

  /// Carbohydrates in grams
  final double? carbohydratesG;
  final double? carbohydratesConfidence;

  /// Protein in grams
  final double? proteinG;
  final double? proteinConfidence;

  /// Total fat in grams
  final double? fatG;
  final double? fatConfidence;

  /// Sodium in milligrams
  final int? sodiumMg;
  final double? sodiumConfidence;

  /// Sugars in grams
  final double? sugarsG;
  final double? sugarsConfidence;

  /// Saturated fat in grams
  final double? saturatedFatG;
  final double? saturatedFatConfidence;

  /// Trans fat in grams
  final double? transFatG;
  final double? transFatConfidence;

  /// Cholesterol in milligrams
  final int? cholesterolMg;
  final double? cholesterolConfidence;

  /// Dietary fiber in grams
  final double? dietaryFiberG;
  final double? dietaryFiberConfidence;

  // ============================================================================
  // Raw Data (always preserved)
  // ============================================================================

  /// Full OCR text output
  final String? ocrFullText;

  /// OCR JSON with language, blocks, etc.
  final Map<String, dynamic>? ocrJson;

  /// Complete nutrition table as JSON
  final Map<String, dynamic>? nutritionRaw;

  /// Raw product info JSON
  final Map<String, dynamic>? productInfoRaw;

  /// Ingredients list text
  final String? ingredientsRaw;

  // ============================================================================
  // Metadata
  // ============================================================================

  /// Image quality assessment
  final String? imageQuality; // 'good', 'medium', 'poor'

  /// Detected language code (e.g., 'ko', 'en')
  final String languageDetected;

  /// Validation status: 'passed', 'warning', 'failed'
  final String validationStatus;

  /// App version that created this scan
  final String? appVersion;

  /// Platform: 'android' or 'ios'
  final String? platform;

  /// Device model (e.g., "SM-G991N")
  final String? deviceModel;

  /// Whether synced to Fivetran/BigQuery
  final bool fivetranSynced;
  final DateTime? fivetranSyncedAt;
  final int fivetranRetryCount;

  /// Nutrition advice from BigQuery alternatives (AI-generated)
  final String? nutritionAdvice;

  // ============================================================================
  // Constructor
  // ============================================================================

  ScanResult({
    required this.scanId,
    required this.timestamp,
    required this.carbRatio,
    required this.proteinRatio,
    required this.fatRatio,
    required this.imageUrl,
    this.productName,
    this.productNameConfidence,
    this.manufacturer,
    this.manufacturerConfidence,
    this.barcode,
    this.barcodeConfidence,
    this.barcodeVerified = false,
    this.foodCategory,
    this.categoryConfidence,
    this.servingSize,
    this.servingSizeConfidence,
    this.calories,
    this.caloriesConfidence,
    this.carbohydratesG,
    this.carbohydratesConfidence,
    this.proteinG,
    this.proteinConfidence,
    this.fatG,
    this.fatConfidence,
    this.sodiumMg,
    this.sodiumConfidence,
    this.sugarsG,
    this.sugarsConfidence,
    this.saturatedFatG,
    this.saturatedFatConfidence,
    this.transFatG,
    this.transFatConfidence,
    this.cholesterolMg,
    this.cholesterolConfidence,
    this.dietaryFiberG,
    this.dietaryFiberConfidence,
    this.ocrFullText,
    this.ocrJson,
    this.nutritionRaw,
    this.productInfoRaw,
    this.ingredientsRaw,
    this.imageQuality,
    this.languageDetected = 'ko',
    required this.validationStatus,
    this.appVersion,
    this.platform,
    this.deviceModel,
    this.fivetranSynced = false,
    this.fivetranSyncedAt,
    this.fivetranRetryCount = 0,
    this.nutritionAdvice,
  }) {
    // Validate ratio sum
    final sum = carbRatio + proteinRatio + fatRatio;
    assert(
      sum == 100,
      'Ratios must sum to 100, got $sum',
    );
  }

  // ============================================================================
  // Serialization
  // ============================================================================

  /// Convert to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'scan_id': scanId,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'carb_ratio': carbRatio,
      'protein_ratio': proteinRatio,
      'fat_ratio': fatRatio,
      'image_url': imageUrl,
      'product_name': productName,
      'product_name_confidence': productNameConfidence,
      'manufacturer': manufacturer,
      'manufacturer_confidence': manufacturerConfidence,
      'barcode': barcode,
      'barcode_confidence': barcodeConfidence,
      'barcode_verified': barcodeVerified ? 1 : 0,
      'food_category': foodCategory,
      'category_confidence': categoryConfidence,
      'serving_size': servingSize,
      'serving_size_confidence': servingSizeConfidence,
      'calories': calories,
      'calories_confidence': caloriesConfidence,
      'carbohydrates_g': carbohydratesG,
      'carbohydrates_confidence': carbohydratesConfidence,
      'protein_g': proteinG,
      'protein_confidence': proteinConfidence,
      'fat_g': fatG,
      'fat_confidence': fatConfidence,
      'sodium_mg': sodiumMg,
      'sodium_confidence': sodiumConfidence,
      'sugars_g': sugarsG,
      'sugars_confidence': sugarsConfidence,
      'saturated_fat_g': saturatedFatG,
      'saturated_fat_confidence': saturatedFatConfidence,
      'trans_fat_g': transFatG,
      'trans_fat_confidence': transFatConfidence,
      'cholesterol_mg': cholesterolMg,
      'cholesterol_confidence': cholesterolConfidence,
      'dietary_fiber_g': dietaryFiberG,
      'dietary_fiber_confidence': dietaryFiberConfidence,
      'ocr_full_text': ocrFullText,
      'ocr_json': ocrJson != null ? jsonEncode(ocrJson) : null,
      'nutrition_raw': nutritionRaw != null ? jsonEncode(nutritionRaw) : null,
      'product_info_raw':
          productInfoRaw != null ? jsonEncode(productInfoRaw) : null,
      'ingredients_raw': ingredientsRaw,
      'image_quality': imageQuality,
      'language_detected': languageDetected,
      'validation_status': validationStatus,
      'app_version': appVersion,
      'platform': platform,
      'device_model': deviceModel,
      'fivetran_synced': fivetranSynced ? 1 : 0,
      'fivetran_synced_at': () {
        final syncedAt = fivetranSyncedAt;
        return syncedAt != null ? syncedAt.millisecondsSinceEpoch ~/ 1000 : null;
      }(),
      'fivetran_retry_count': fivetranRetryCount,
      'nutrition_advice': nutritionAdvice,
    };
  }

  /// Create from Map (SQLite row)
  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      scanId: map['scan_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as int) * 1000),
      carbRatio: map['carb_ratio'] as int,
      proteinRatio: map['protein_ratio'] as int,
      fatRatio: map['fat_ratio'] as int,
      imageUrl: map['image_url'] as String,
      productName: map['product_name'] as String?,
      productNameConfidence: map['product_name_confidence'] as double?,
      manufacturer: map['manufacturer'] as String?,
      manufacturerConfidence: map['manufacturer_confidence'] as double?,
      barcode: map['barcode'] as String?,
      barcodeConfidence: map['barcode_confidence'] as double?,
      barcodeVerified: (map['barcode_verified'] as int?) == 1,
      foodCategory: map['food_category'] as String?,
      categoryConfidence: map['category_confidence'] as double?,
      servingSize: map['serving_size'] as String?,
      servingSizeConfidence: map['serving_size_confidence'] as double?,
      calories: _parseIntSafely(map['calories']),
      caloriesConfidence: map['calories_confidence'] as double?,
      carbohydratesG: map['carbohydrates_g'] as double?,
      carbohydratesConfidence: map['carbohydrates_confidence'] as double?,
      proteinG: map['protein_g'] as double?,
      proteinConfidence: map['protein_confidence'] as double?,
      fatG: map['fat_g'] as double?,
      fatConfidence: map['fat_confidence'] as double?,
      sodiumMg: _parseIntSafely(map['sodium_mg']),
      sodiumConfidence: map['sodium_confidence'] as double?,
      sugarsG: map['sugars_g'] as double?,
      sugarsConfidence: map['sugars_confidence'] as double?,
      saturatedFatG: map['saturated_fat_g'] as double?,
      saturatedFatConfidence: map['saturated_fat_confidence'] as double?,
      transFatG: map['trans_fat_g'] as double?,
      transFatConfidence: map['trans_fat_confidence'] as double?,
      cholesterolMg: _parseIntSafely(map['cholesterol_mg']),
      cholesterolConfidence: map['cholesterol_confidence'] as double?,
      dietaryFiberG: map['dietary_fiber_g'] as double?,
      dietaryFiberConfidence: map['dietary_fiber_confidence'] as double?,
      ocrFullText: map['ocr_full_text'] as String?,
      ocrJson: map['ocr_json'] != null
          ? jsonDecode(map['ocr_json'] as String) as Map<String, dynamic>
          : null,
      nutritionRaw: map['nutrition_raw'] != null
          ? jsonDecode(map['nutrition_raw'] as String) as Map<String, dynamic>
          : null,
      productInfoRaw: map['product_info_raw'] != null
          ? jsonDecode(map['product_info_raw'] as String)
              as Map<String, dynamic>
          : null,
      ingredientsRaw: map['ingredients_raw'] as String?,
      imageQuality: map['image_quality'] as String?,
      languageDetected:
          map['language_detected'] as String? ?? 'ko',
      validationStatus: map['validation_status'] as String,
      appVersion: map['app_version'] as String?,
      platform: map['platform'] as String?,
      deviceModel: map['device_model'] as String?,
      fivetranSynced: (map['fivetran_synced'] as int?) == 1,
      fivetranSyncedAt: map['fivetran_synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['fivetran_synced_at'] as int) * 1000)
          : null,
      fivetranRetryCount: map['fivetran_retry_count'] as int? ?? 0,
      nutritionAdvice: map['nutrition_advice'] as String?,
    );
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

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

  /// Create a copy with modified fields
  ScanResult copyWith({
    String? scanId,
    DateTime? timestamp,
    int? carbRatio,
    int? proteinRatio,
    int? fatRatio,
    String? imageUrl,
    String? productName,
    double? productNameConfidence,
    String? manufacturer,
    double? manufacturerConfidence,
    String? barcode,
    double? barcodeConfidence,
    bool? barcodeVerified,
    String? foodCategory,
    double? categoryConfidence,
    String? servingSize,
    double? servingSizeConfidence,
    int? calories,
    double? caloriesConfidence,
    double? carbohydratesG,
    double? carbohydratesConfidence,
    double? proteinG,
    double? proteinConfidence,
    double? fatG,
    double? fatConfidence,
    int? sodiumMg,
    double? sodiumConfidence,
    double? sugarsG,
    double? sugarsConfidence,
    double? saturatedFatG,
    double? saturatedFatConfidence,
    double? transFatG,
    double? transFatConfidence,
    int? cholesterolMg,
    double? cholesterolConfidence,
    double? dietaryFiberG,
    double? dietaryFiberConfidence,
    String? ocrFullText,
    Map<String, dynamic>? ocrJson,
    Map<String, dynamic>? nutritionRaw,
    Map<String, dynamic>? productInfoRaw,
    String? ingredientsRaw,
    String? imageQuality,
    String? languageDetected,
    String? validationStatus,
    String? appVersion,
    String? platform,
    String? deviceModel,
    bool? fivetranSynced,
    DateTime? fivetranSyncedAt,
    int? fivetranRetryCount,
    String? nutritionAdvice,
  }) {
    return ScanResult(
      scanId: scanId ?? this.scanId,
      timestamp: timestamp ?? this.timestamp,
      carbRatio: carbRatio ?? this.carbRatio,
      proteinRatio: proteinRatio ?? this.proteinRatio,
      fatRatio: fatRatio ?? this.fatRatio,
      imageUrl: imageUrl ?? this.imageUrl,
      productName: productName ?? this.productName,
      productNameConfidence:
          productNameConfidence ?? this.productNameConfidence,
      manufacturer: manufacturer ?? this.manufacturer,
      manufacturerConfidence:
          manufacturerConfidence ?? this.manufacturerConfidence,
      barcode: barcode ?? this.barcode,
      barcodeConfidence: barcodeConfidence ?? this.barcodeConfidence,
      barcodeVerified: barcodeVerified ?? this.barcodeVerified,
      foodCategory: foodCategory ?? this.foodCategory,
      categoryConfidence: categoryConfidence ?? this.categoryConfidence,
      servingSize: servingSize ?? this.servingSize,
      servingSizeConfidence:
          servingSizeConfidence ?? this.servingSizeConfidence,
      calories: calories ?? this.calories,
      caloriesConfidence: caloriesConfidence ?? this.caloriesConfidence,
      carbohydratesG: carbohydratesG ?? this.carbohydratesG,
      carbohydratesConfidence:
          carbohydratesConfidence ?? this.carbohydratesConfidence,
      proteinG: proteinG ?? this.proteinG,
      proteinConfidence: proteinConfidence ?? this.proteinConfidence,
      fatG: fatG ?? this.fatG,
      fatConfidence: fatConfidence ?? this.fatConfidence,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sodiumConfidence: sodiumConfidence ?? this.sodiumConfidence,
      sugarsG: sugarsG ?? this.sugarsG,
      sugarsConfidence: sugarsConfidence ?? this.sugarsConfidence,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      saturatedFatConfidence:
          saturatedFatConfidence ?? this.saturatedFatConfidence,
      transFatG: transFatG ?? this.transFatG,
      transFatConfidence: transFatConfidence ?? this.transFatConfidence,
      cholesterolMg: cholesterolMg ?? this.cholesterolMg,
      cholesterolConfidence:
          cholesterolConfidence ?? this.cholesterolConfidence,
      dietaryFiberG: dietaryFiberG ?? this.dietaryFiberG,
      dietaryFiberConfidence:
          dietaryFiberConfidence ?? this.dietaryFiberConfidence,
      ocrFullText: ocrFullText ?? this.ocrFullText,
      ocrJson: ocrJson ?? this.ocrJson,
      nutritionRaw: nutritionRaw ?? this.nutritionRaw,
      productInfoRaw: productInfoRaw ?? this.productInfoRaw,
      ingredientsRaw: ingredientsRaw ?? this.ingredientsRaw,
      imageQuality: imageQuality ?? this.imageQuality,
      languageDetected: languageDetected ?? this.languageDetected,
      validationStatus: validationStatus ?? this.validationStatus,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      deviceModel: deviceModel ?? this.deviceModel,
      fivetranSynced: fivetranSynced ?? this.fivetranSynced,
      fivetranSyncedAt: fivetranSyncedAt ?? this.fivetranSyncedAt,
      fivetranRetryCount: fivetranRetryCount ?? this.fivetranRetryCount,
      nutritionAdvice: nutritionAdvice ?? this.nutritionAdvice,
    );
  }

  /// Format ratio for display: "🥖50 🍗30 🥑20"
  String get formattedRatio {
    return '🥖$carbRatio 🍗$proteinRatio 🥑$fatRatio';
  }

  @override
  String toString() {
    return 'ScanResult(scanId: $scanId, timestamp: $timestamp, '
        'ratios: $carbRatio/$proteinRatio/$fatRatio, '
        'validationStatus: $validationStatus)';
  }
}
