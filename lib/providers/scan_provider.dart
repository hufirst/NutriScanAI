import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import '../models/scan_result.dart';
import '../models/ratio_data.dart';
import '../models/user_profile.dart';
import '../services/gemini_service.dart';
import '../services/validation_service.dart';
import '../services/storage_service.dart';
import '../services/user_profile_service.dart';
import '../utils/error_handler.dart';
import '../utils/constants.dart';

/// Provider for nutrition scan operations
///
/// Manages scan workflow: camera → Gemini → validation → storage → state update
class ScanProvider extends ChangeNotifier {
  final GeminiService _geminiService;
  final ValidationService _validationService;
  final StorageService _storageService;
  final UserProfileService _userProfileService;
  final _uuid = const Uuid();

  // State
  bool _isScanning = false;
  String? _errorMessage;
  ScanResult? _lastScanResult;
  double _scanProgress = 0.0;
  List<ScanResult> _scanHistory = [];
  bool _isLoadingHistory = false;

  ScanProvider({
    GeminiService? geminiService,
    ValidationService? validationService,
    StorageService? storageService,
    UserProfileService? userProfileService,
  })  : _geminiService = geminiService ?? GeminiService(
          bigQueryProjectId: dotenv.env['BIGQUERY_PROJECT_ID'],
        ),
        _validationService = validationService ?? ValidationService(),
        _storageService = storageService ?? StorageService(),
        _userProfileService = userProfileService ?? UserProfileService() {
    // Initialize services
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _userProfileService.initialize();
    loadHistory();
  }

  // Getters
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  ScanResult? get lastScanResult => _lastScanResult;
  double get scanProgress => _scanProgress;
  List<ScanResult> get scanHistory => _scanHistory;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Main scan workflow: image → Gemini → validation → storage
  ///
  /// [imagePath] Local file path to captured nutrition label image
  /// Returns ScanResult if successful, null if failed
  Future<ScanResult?> scanImage(String imagePath) async {
    try {
      final totalStart = DateTime.now();
      _setScanning(true);
      _clearError();
      _updateProgress(0.0);

      // Step 1: Call Gemini API with retry logic (0.0 → 0.5)
      _updateProgress(0.1);
      final step1Start = DateTime.now();
      final geminiResponse = await ErrorHandler.withRetry(
        () => _geminiService.analyzeNutritionLabel(imagePath),
        onRetry: (attempt, error) {
          debugPrint('Gemini API retry attempt $attempt: $error');
        },
      );
      final step1Duration = DateTime.now().difference(step1Start).inMilliseconds;
      debugPrint('⏱️ Step 1 (Gemini OCR+Analysis): ${step1Duration}ms');
      _updateProgress(0.5);

      // Step 2: Validate response (0.5 → 0.6)
      final step2Start = DateTime.now();
      final scanId = _uuid.v4();
      final validationReport = _validationService.validate(scanId, geminiResponse);
      final validationStatus = _validationService.getValidationStatus(validationReport);
      final step2Duration = DateTime.now().difference(step2Start).inMilliseconds;
      debugPrint('⏱️ Step 2 (Validation): ${step2Duration}ms');
      _updateProgress(0.6);

      // Step 3: Save image to permanent location (0.6 → 0.7)
      final step3Start = DateTime.now();
      final savedImagePath = await _saveImage(imagePath, scanId);
      final step3Duration = DateTime.now().difference(step3Start).inMilliseconds;
      debugPrint('⏱️ Step 3 (Save Image): ${step3Duration}ms');
      _updateProgress(0.7);

      // Step 4: Generate nutrition advice with BigQuery alternatives (0.7 → 0.8)
      final step4Start = DateTime.now();
      String? nutritionAdvice;
      try {
        final userProfile = await _userProfileService.loadProfile();
        nutritionAdvice = await _geminiService.generateNutritionAdvice(
          nutritionAnalysis: geminiResponse,
          userProfile: userProfile,
        );
        debugPrint('✅ Generated nutrition advice with BigQuery alternatives');
      } catch (e) {
        debugPrint('⚠️ Failed to generate nutrition advice: $e');
        nutritionAdvice = null;
      }
      final step4Duration = DateTime.now().difference(step4Start).inMilliseconds;
      debugPrint('⏱️ Step 4 (BigQuery+Advice): ${step4Duration}ms');
      _updateProgress(0.8);

      // Step 5: Build ScanResult with nutrition advice (0.8 → 0.9)
      final step5Start = DateTime.now();
      final scanResult = await _buildScanResult(
        scanId: scanId,
        imagePath: savedImagePath,
        geminiResponse: geminiResponse,
        validationStatus: validationStatus,
        nutritionAdvice: nutritionAdvice,
      );
      final step5Duration = DateTime.now().difference(step5Start).inMilliseconds;
      debugPrint('⏱️ Step 5 (Build ScanResult): ${step5Duration}ms');
      _updateProgress(0.9);

      // Step 6: Save to database (0.9 → 0.95)
      final step6Start = DateTime.now();
      await _storageService.insertScanResult(scanResult.toMap());

      // Save validation report if not passed
      if (validationStatus != AppConstants.validationStatusPassed) {
        await _storageService.insertValidationReport(validationReport.toMap());
      }
      final step6Duration = DateTime.now().difference(step6Start).inMilliseconds;
      debugPrint('⏱️ Step 6 (Database): ${step6Duration}ms');
      _updateProgress(0.95);

      // Step 7: Update state (0.95 → 1.0)
      final step7Start = DateTime.now();
      _lastScanResult = scanResult;
      _scanHistory.insert(0, scanResult); // Add to beginning (newest first)
      final step7Duration = DateTime.now().difference(step7Start).inMilliseconds;
      debugPrint('⏱️ Step 7 (State Update): ${step7Duration}ms');
      _updateProgress(1.0);

      final totalDuration = DateTime.now().difference(totalStart).inMilliseconds;
      debugPrint('⏱️ ========================================');
      debugPrint('⏱️ TOTAL SCAN TIME: ${totalDuration}ms (${(totalDuration / 1000).toStringAsFixed(1)}s)');
      debugPrint('⏱️ ========================================');

      return scanResult;
    } catch (e, stackTrace) {
      final errorMsg = ErrorHandler.formatUserMessage(e);
      _setError(errorMsg);
      debugPrint('=== SCAN ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('==================');
      rethrow; // Re-throw to let HomeScreen handle it
    } finally {
      _setScanning(false);
      _updateProgress(0.0);
    }
  }

  /// Save captured image to app's permanent storage
  Future<String> _saveImage(String tempPath, String scanId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/images');

    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    final fileName = '$scanId.jpg';
    final savedPath = '${imageDir.path}/$fileName';

    await File(tempPath).copy(savedPath);

    return savedPath;
  }

  /// Build ScanResult from Gemini response
  Future<ScanResult> _buildScanResult({
    required String scanId,
    required String imagePath,
    required Map<String, dynamic> geminiResponse,
    required String validationStatus,
    String? nutritionAdvice,
  }) async {
    final nutrition = geminiResponse['nutrition'] as Map<String, dynamic>;
    final rawData = geminiResponse['raw_data'] as Map<String, dynamic>;
    final classifiedData = geminiResponse['classified_data'] as Map<String, dynamic>?;
    final metadata = geminiResponse['metadata'] as Map<String, dynamic>?;

    // Recalculate ratios from nutrition data to ensure sum = 100
    // Use RatioData.fromNutrition() for smart rounding
    final carbG = (nutrition['carbohydrates_g'] as num?)?.toDouble() ?? 0.0;
    final proteinG = (nutrition['protein_g'] as num?)?.toDouble() ?? 0.0;
    final fatG = (nutrition['fat_g'] as num?)?.toDouble() ?? 0.0;

    final ratioData = RatioData.fromNutrition(
      carbohydratesG: carbG,
      proteinG: proteinG,
      fatG: fatG,
    );

    // Filter classified data by confidence threshold
    final filteredClassified = _filterByConfidence(classifiedData);

    return ScanResult(
      scanId: scanId,
      timestamp: DateTime.now(),
      carbRatio: ratioData.carbRatio,
      proteinRatio: ratioData.proteinRatio,
      fatRatio: ratioData.fatRatio,
      imageUrl: imagePath,

      // Classified data (only if confidence ≥ 0.85)
      productName: filteredClassified['product_name'] as String?,
      productNameConfidence: filteredClassified['product_name_confidence'] as double?,
      manufacturer: filteredClassified['manufacturer'] as String?,
      manufacturerConfidence: filteredClassified['manufacturer_confidence'] as double?,
      barcode: filteredClassified['barcode'] as String?,
      barcodeConfidence: filteredClassified['barcode_confidence'] as double?,
      foodCategory: filteredClassified['food_category'] as String?,
      categoryConfidence: filteredClassified['category_confidence'] as double?,

      // Nutrition facts
      servingSize: nutrition['serving_size'] as String?,
      calories: _parseIntSafely(nutrition['calories']),
      carbohydratesG: (nutrition['carbohydrates_g'] as num?)?.toDouble(),
      proteinG: (nutrition['protein_g'] as num?)?.toDouble(),
      fatG: (nutrition['fat_g'] as num?)?.toDouble(),
      sodiumMg: _parseIntSafely(nutrition['sodium_mg']),
      sugarsG: (nutrition['sugars_g'] as num?)?.toDouble(),
      saturatedFatG: (nutrition['saturated_fat_g'] as num?)?.toDouble(),
      transFatG: (nutrition['trans_fat_g'] as num?)?.toDouble(),
      cholesterolMg: _parseIntSafely(nutrition['cholesterol_mg']),
      dietaryFiberG: (nutrition['dietary_fiber_g'] as num?)?.toDouble(),

      // Raw data (always preserved)
      ocrFullText: rawData['ocr_full_text'] as String?,
      nutritionRaw: rawData,
      productInfoRaw: classifiedData,
      ingredientsRaw: rawData['ingredients_text'] as String?,

      // Metadata
      imageQuality: metadata?['image_quality'] as String?,
      languageDetected: metadata?['language_detected'] as String? ?? 'ko',
      validationStatus: validationStatus,
      platform: Platform.isAndroid ? 'android' : 'ios',
      nutritionAdvice: nutritionAdvice,
    );
  }

  /// Filter classified data by confidence threshold
  Map<String, dynamic> _filterByConfidence(Map<String, dynamic>? data) {
    if (data == null) return {};

    final filtered = <String, dynamic>{};

    data.forEach((key, value) {
      if (key.endsWith('_confidence')) {
        // Keep confidence scores
        filtered[key] = value;
      } else {
        // Check if corresponding confidence score meets threshold
        final confidenceKey = '${key}_confidence';
        if (data.containsKey(confidenceKey)) {
          final confidence = data[confidenceKey] as double?;
          if (confidence != null && confidence >= AppConstants.confidenceThreshold) {
            filtered[key] = value;
            filtered[confidenceKey] = confidence;
          }
        }
      }
    });

    return filtered;
  }

  /// Safely parse integer from dynamic value (handles String, int, double)
  int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }

  /// Load scan history from database
  Future<void> loadHistory({int limit = 100}) async {
    try {
      _isLoadingHistory = true;
      notifyListeners();

      final maps = await _storageService.getAllScanResults(limit: limit);
      _scanHistory = maps.map((map) => ScanResult.fromMap(map)).toList();

      // Set last scan result to most recent
      if (_scanHistory.isNotEmpty) {
        _lastScanResult = _scanHistory.first;
      }

      debugPrint('Loaded ${_scanHistory.length} scan results from database');
    } catch (e) {
      debugPrint('Failed to load scan history: $e');
      _scanHistory = [];
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Clear last scan result
  void clearLastScan() {
    _lastScanResult = null;
    _clearError();
    notifyListeners();
  }

  /// Clear all scan history
  Future<void> clearHistory() async {
    try {
      await _storageService.deleteAllScanResults();
      _scanHistory = [];
      _lastScanResult = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear history: $e');
      rethrow;
    }
  }

  // State management helpers
  void _setScanning(bool value) {
    _isScanning = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _updateProgress(double value) {
    _scanProgress = value;
    notifyListeners();
  }
}
