import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/constants.dart';
import '../models/nutrition_data.dart';
import '../models/ratio_data.dart';
import '../models/user_profile.dart';
import 'user_profile_service.dart';
import 'bigquery_service.dart';

/// Service for analyzing nutrition labels using Gemini 2.0-flash API
///
/// Implements OCR extraction, nutrition parsing, and ratio calculation
/// with confidence-based classification and raw data preservation.
class GeminiService {
  late final GenerativeModel _model;
  final String _apiKey;
  final UserProfileService _userProfileService = UserProfileService();
  bool _profileServiceInitialized = false;

  // BigQuery integration (optional - works offline if not configured)
  BigQueryService? _bigQueryService;

  GeminiService({String? apiKey, String? bigQueryProjectId})
      : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw ArgumentError('GEMINI_API_KEY is required');
    }

    _model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1, // Low temperature for consistency
        topK: 1,
        topP: 1.0,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
      ),
    );

    // Initialize BigQuery if project ID provided
    if (bigQueryProjectId != null && bigQueryProjectId.isNotEmpty) {
      _bigQueryService = BigQueryService(projectId: bigQueryProjectId);
      debugPrint('✅ BigQuery service initialized for project: $bigQueryProjectId');
    } else {
      debugPrint('ℹ️ BigQuery service not initialized (offline mode)');
    }
  }

  /// Initialize user profile service (call once at app startup)
  Future<void> initializeProfileService() async {
    if (!_profileServiceInitialized) {
      await _userProfileService.initialize();
      _profileServiceInitialized = true;
    }
  }

  /// Analyze nutrition label image and extract structured data
  ///
  /// [imagePath] Local file path to the nutrition label image
  /// Returns complete nutrition analysis with raw and classified data
  /// Throws [GeminiException] on API errors
  Future<Map<String, dynamic>> analyzeNutritionLabel(String imagePath) async {
    try {
      debugPrint('=== GEMINI API CALL START ===');
      debugPrint('Image path: $imagePath');

      // Ensure profile service is initialized
      await initializeProfileService();

      // Read image file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw GeminiException('Image file not found: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      debugPrint('Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      final imagePart = DataPart('image/jpeg', imageBytes);

      // Build prompt (with user profile context)
      final prompt = TextPart(await _buildPrompt());

      // Create content
      final content = [
        Content.multi([prompt, imagePart])
      ];

      debugPrint('Calling Gemini API (timeout: ${AppConstants.geminiTimeout.inSeconds}s)...');

      // Call Gemini API with timeout
      final response = await _model
          .generateContent(content)
          .timeout(AppConstants.geminiTimeout, onTimeout: () {
        debugPrint('⚠️ TIMEOUT after ${AppConstants.geminiTimeout.inSeconds}s');
        throw GeminiException('Gemini API timeout after ${AppConstants.geminiTimeout.inSeconds}s');
      });

      // Parse response
      if (response.text == null || response.text!.isEmpty) {
        throw GeminiException('Empty response from Gemini API');
      }

      debugPrint('=== GEMINI RAW RESPONSE ===');
      debugPrint(response.text!);
      debugPrint('===========================');

      Map<String, dynamic> jsonData;

      try {
        jsonData = jsonDecode(response.text!);
      } on FormatException catch (e) {
        // Attempt to sanitize and retry
        debugPrint('⚠️ Initial JSON parse failed, attempting sanitization...');
        debugPrint('Parse error: ${e.message}');

        final sanitized = _sanitizeJson(response.text!);
        try {
          jsonData = jsonDecode(sanitized);
          debugPrint('✓ Successfully parsed after sanitization');
        } catch (e2) {
          debugPrint('✗ Sanitization failed');
          throw GeminiException(
            'Failed to parse JSON response even after sanitization.\n'
            'Original error: ${e.message}\n'
            'Response length: ${response.text!.length} characters'
          );
        }
      }

      debugPrint('=== GEMINI PARSED JSON ===');
      debugPrint(jsonData.toString());
      debugPrint('==========================');

      // Validate required fields
      _validateResponse(jsonData);

      return jsonData as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw GeminiException('Failed to parse JSON response: ${e.message}');
    } on TimeoutException {
      throw GeminiException('Gemini API request timed out');
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Unexpected error: $e');
    }
  }

  /// Sanitize malformed JSON by attempting to fix common issues
  String _sanitizeJson(String jsonText) {
    // This is a best-effort attempt to fix common JSON formatting issues
    // from Gemini responses, particularly unterminated strings in raw_data fields

    // Strategy: Extract the nutrition and ratio sections which are reliable,
    // and truncate or fix the raw_data section if it's causing issues

    try {
      // First, try to find where the JSON is broken
      // Common issue: unterminated strings in raw_data fields

      // Look for the raw_data section
      final rawDataIndex = jsonText.indexOf('"raw_data"');
      if (rawDataIndex == -1) {
        // No raw_data section, return as is
        return jsonText;
      }

      // Try to extract everything before raw_data and reconstruct
      final beforeRawData = jsonText.substring(0, rawDataIndex);

      // Create minimal valid raw_data section
      final minimalRawData = '''
  "raw_data": {
    "ocr_full_text": "",
    "nutrition_table_text": "",
    "ingredients_text": "",
    "package_text_all": ""
  },
  "classified_data": null,
  "metadata": {
    "image_quality": "medium",
    "language_detected": "ko"
  }
}''';

      // Reconstruct JSON
      return beforeRawData + minimalRawData;
    } catch (e) {
      debugPrint('Sanitization error: $e');
      return jsonText; // Return original if sanitization fails
    }
  }

  /// Build the prompt for Gemini API (with optional user profile context)
  Future<String> _buildPrompt() async {
    // Get personalized prompt suffix from user profile
    final profileSuffix = await _userProfileService.generatePersonalizedPromptSuffix();

    return '''
You are an expert food nutrition analysis system specialized in Korean food.

Your tasks:
1. FIRST, detect image type: nutrition label OR general food photo
2. Extract/estimate nutrition information based on image type
3. Return well-formatted JSON with proper Korean text encoding

## Image Type Detection

**NUTRITION LABEL**: Contains text like "영양정보", "영양성분", nutrition table with values
**FOOD PHOTO**: Shows actual food/dish without nutrition label

## For NUTRITION LABELS:
1. Extract ALL text visible in the image (raw OCR)
2. Parse structured nutrition facts with confidence scores
3. Classify product information ONLY if confidence >= 0.8
4. Calculate carbohydrate:protein:fat ratio as percentage of total calories

## For FOOD PHOTOS (without nutrition label):
1. Identify the food/dish shown
2. ESTIMATE typical nutrition values based on visual analysis
3. Set all confidence scores to 0.6-0.7 (estimation range)
4. Add "data_source": "estimation" to metadata
5. Calculate ratio based on estimated values

Rules:
- Always capture raw OCR text (even if empty for food photos)
- For labels: Never guess, return null for uncertain fields
- For food photos: Provide reasonable estimates based on typical values
- Confidence scores must be realistic (0.0 to 1.0)
- Nutrition ratio must sum to 100% (±5% tolerance allowed)
- CRITICAL: Properly escape all special characters in JSON strings (quotes, newlines, backslashes)
- Replace newlines with \\n, quotes with \\\", backslashes with \\\\

Analyze this Korean food image (nutrition label OR food photo) and extract/estimate data according to the following structure.

## Required Output JSON

{
  "nutrition": {
    "serving_size": "100g",
    "serving_size_confidence": 0.95,
    "calories": 250,
    "calories_confidence": 0.95,
    "carbohydrates_g": 30.5,
    "carbohydrates_confidence": 0.95,
    "protein_g": 10.0,
    "protein_confidence": 0.95,
    "fat_g": 5.2,
    "fat_confidence": 0.95,
    "sodium_mg": 450,
    "sodium_confidence": 0.90,
    "sugars_g": 12.0,
    "sugars_confidence": 0.85,
    "saturated_fat_g": 2.0,
    "saturated_fat_confidence": 0.85,
    "trans_fat_g": 0.0,
    "trans_fat_confidence": 0.90,
    "cholesterol_mg": 0,
    "cholesterol_confidence": 0.80,
    "dietary_fiber_g": 2.5,
    "dietary_fiber_confidence": 0.85
  },

  "ratio": {
    "carb_ratio": 60,
    "protein_ratio": 20,
    "fat_ratio": 20
  },

  "raw_data": {
    "ocr_full_text": "영양정보\\n1회 제공량 100g\\n열량 250kcal\\n탄수화물 30.5g\\n...",
    "nutrition_table_text": "탄수화물 30.5g\\n당류 12g\\n단백질 10g\\n지방 5.2g\\n...",
    "ingredients_text": "밀가루, 설탕, 식물성유지, 소금, 계란...",
    "package_text_all": "제품명: XXX\\n제조사: YYY\\n바코드: 8801234567890\\n..."
  },

  "classified_data": {
    "product_name": "초코칩 쿠키",
    "product_name_confidence": 0.92,
    "manufacturer": "ABC식품",
    "manufacturer_confidence": 0.88,
    "barcode": "8801234567890",
    "barcode_confidence": 0.95,
    "food_category": "과자류",
    "category_confidence": 0.85
  },

  "metadata": {
    "image_quality": "good",
    "language_detected": "ko",
    "data_source": "label"
  }
}

**IMPORTANT**: Set "data_source" field:
- "label" = nutrition label with exact values (high confidence 0.85-0.95)
- "estimation" = food photo with estimated values (medium confidence 0.6-0.7)

## Extraction Rules

### For Nutrition Labels - Extraction Rules (필수)
1. **Serving Size**: Look for "1회 제공량", "총 내용량", "100g당"
2. **Calories**: Look for "열량", "에너지", "kcal" (convert kJ if needed: 1 kcal = 4.184 kJ)
3. **Carbohydrates**: Look for "탄수화물", include "당류 (sugars)" separately
4. **Protein**: Look for "단백질"
5. **Fat**: Look for "지방", include saturated/trans fat separately

### For Food Photos - Estimation Rules (일반 음식 사진)

**STEP 1: Food Identification (음식 인식)**
IMPORTANT: Always try to identify the specific food first. Never return "식별되지 않은 음식" unless absolutely unrecognizable.

Follow this priority order:
1. **Simple Raw Foods** (가장 먼저 확인 - 단순 음식)
   - **과일 (Fruits)**:
     * 감귤류: 귤(orange), 오렌지(round orange), 레몬(yellow lemon), 자몽(large pink)
     * 사과류: 사과(red/green apple), 배(yellow pear)
     * 열대과일: 바나나(yellow curved), 키위(brown fuzzy), 파인애플(yellow spiky)
     * 베리류: 딸기(red with seeds), 포도(grape clusters), 블루베리(tiny blue)
     * 기타: 수박(green outside red inside), 참외(yellow striped), 복숭아(fuzzy orange/pink)

   - **채소 (Vegetables)**:
     * 잎채소: 상추(lettuce), 배추(napa cabbage), 양배추(cabbage)
     * 뿌리채소: 당근(orange carrot), 무(white radish), 감자(brown potato), 고구마(sweet potato)
     * 기타: 토마토(red/yellow round), 오이(green cucumber), 양파(onion), 브로콜리(green tree-like)

   - **빵/제과 (Breads)**: 식빵(sliced bread), 바게트(long thin), 크루아상(crescent), 도넛(ring shape)

   - **유제품 (Dairy)**: 우유(milk carton/glass), 요구르트(yogurt cup), 치즈(cheese block/slice)

   - **견과류 (Nuts)**: 아몬드(almond), 호두(walnut), 땅콩(peanut)

2. **Korean Cuisine** (한식 - 조리된 음식)
   - 밥류: 흰밥, 볶음밥, 비빔밥, 김밥, 덮밥, 회덮밥
   - 국/찌개/탕: 된장찌개, 김치찌개, 부대찌개, 순두부찌개, 삼계탕, 감자탕, 순대국밥
   - 고기구이: 삼겹살, 갈비, 불고기
   - 치킨: 후라이드, 양념, 간장
   - 면류: 라면, 짜장면, 짬뽕, 냉면
   - 분식: 떡볶이, 순대, 김밥
   - 반찬: 깍두기, 도토리묵, 각종 나물
   - 떡/디저트: 인절미, 송편, 화채

3. **Other Cuisines** (기타 요리)
   - 중식: 탕수육, 짬뽕, 짜장면
   - 일식: 초밥, 라멘, 돈까스
   - 양식: 스테이크, 파스타, 피자, 햄버거

4. **Visual Recognition Strategy** (시각적 인식 전략)
   - **Color**: Primary identification clue
     * Orange/Yellow round = 귤 (mandarin orange)
     * Red round with seeds = 딸기 (strawberry)
     * Yellow curved = 바나나 (banana)
     * Green long = 오이 (cucumber)
     * Orange long = 당근 (carrot)

   - **Shape**: Secondary confirmation
     * Spherical/Round: 과일 대부분
     * Long/Cylindrical: 바나나, 오이, 당근
     * Tree-like: 브로콜리
     * Ring: 도넛

   - **Texture/Surface**:
     * Smooth shiny: 사과, 토마토
     * Rough/dimpled: 귤, 오렌지
     * Fuzzy: 복숭아, 키위

5. **Confidence Guidelines** (신뢰도 기준)
   - 0.9-1.0: 명확한 단순 식품 (귤, 바나나, 사과 등)
   - 0.8-0.9: 명확한 조리 음식 (비빔밥, 김치찌개 등)
   - 0.6-0.7: 일반적인 음식
   - 0.4-0.5: 불명확하지만 추정 가능
   - Only use "식별되지 않은 음식" if confidence < 0.3

REMEMBER: 귤 (mandarin orange) is extremely common and easy to identify by:
- Orange color
- Rough/dimpled peel surface
- Spherical shape
- Often peeled showing segments

**STEP 2: Nutrition Estimation**
2. **Estimate serving size**: Based on visual portion
   - Fruits: "1개" (1 piece), "100g" (100 grams)
   - Vegetables: "1개" or "100g"
   - Meals: "1인분 약 300g" (1 serving approx 300g)

3. **Estimate nutrition per 100g**: Use typical values for that food type

   **FRUITS** (과일 - per 100g):
   - 귤 (mandarin) ≈ 50kcal, 탄12g, 단1g, 지0.3g
   - 사과 (apple) ≈ 52kcal, 탄14g, 단0.3g, 지0.2g
   - 바나나 (banana) ≈ 89kcal, 탄23g, 단1.1g, 지0.3g
   - 딸기 (strawberry) ≈ 32kcal, 탄8g, 단0.7g, 지0.3g
   - 포도 (grape) ≈ 69kcal, 탄18g, 단0.7g, 지0.2g

   **VEGETABLES** (채소 - per 100g):
   - 토마토 (tomato) ≈ 18kcal, 탄4g, 단0.9g, 지0.2g
   - 오이 (cucumber) ≈ 15kcal, 탄3.6g, 단0.7g, 지0.1g
   - 당근 (carrot) ≈ 41kcal, 탄10g, 단0.9g, 지0.2g
   - 브로콜리 (broccoli) ≈ 34kcal, 탄7g, 단2.8g, 지0.4g

   **KOREAN MEALS** (한식 - per 100g):
   - 치킨 (fried chicken) ≈ 250kcal, 탄20g, 단25g, 지15g
   - 비빔밥 ≈ 150kcal, 탄25g, 단8g, 지3g
   - 삼계탕 ≈ 120kcal, 탄5g, 단15g, 지5g
   - 회덮밥 ≈ 160kcal, 탄28g, 단12g, 지2g
   - 감자탕 ≈ 80kcal, 탄8g, 단8g, 지3g
   - 순대국밥 ≈ 100kcal, 탄12g, 단8g, 지3g

   **SNACKS/DESSERTS** (간식/디저트 - per 100g):
   - 인절미 ≈ 200kcal, 탄40g, 단5g, 지3g
   - 화채 ≈ 50kcal, 탄12g, 단0.5g, 지0.2g
   - 식빵 (bread) ≈ 265kcal, 탄49g, 단9g, 지4g

4. **Set confidence**:
   - 0.9-1.0: 명확한 단순 식품 (귤, 바나나, 사과 등)
   - 0.8-0.9: 명확한 조리 음식 (비빔밥, 김치찌개, 치킨, 삼계탕 등)
   - 0.6-0.7: 일반적인 음식
   - 0.4-0.5: 불명확한 음식

5. **Set data_source**: "estimation" in metadata

6. **Fill classified_data**:
   - product_name: 한국어 음식명 (예: "귤", "사과", "삼겹살", "김치찌개")
   - food_category: 음식 카테고리
     * 과일: "과일"
     * 채소: "채소"
     * 한식: "한식 고기구이", "한식 찌개", "한식 탕" 등
   - manufacturer: null (일반 음식은 제조사 없음)

### Ratio Calculation (필수)
carb_calories = carbohydrates_g * 4
protein_calories = protein_g * 4
fat_calories = fat_g * 9
total_calories = carb_calories + protein_calories + fat_calories
carb_ratio = round((carb_calories / total_calories) * 100)
protein_ratio = round((protein_calories / total_calories) * 100)
fat_ratio = round((fat_calories / total_calories) * 100)
// Ensure sum = 100 (adjust largest component if needed)

### Confidence Score Guidelines
- **0.95-1.0**: Clear and standard format
- **0.85-0.94**: Readable but slightly unclear
- **0.70-0.84**: Guessable but uncertain
- **< 0.70**: Uncertain, return null

### Korean Terms
- "영양정보" = Nutrition Facts
- "1회 제공량" = Serving Size
- "열량" = Calories
- "탄수화물" = Carbohydrate
- "당류" = Sugars
- "단백질" = Protein
- "지방" = Fat
- "포화지방" = Saturated Fat
- "트랜스지방" = Trans Fat
- "나트륨" = Sodium
- "콜레스테롤" = Cholesterol

Please analyze the image and return the JSON structure with all available data.

$profileSuffix
''';
  }

  /// Validate API response contains required fields
  void _validateResponse(Map<String, dynamic> data) {
    // Check for error field
    if (data.containsKey('error')) {
      throw GeminiException(
          'Gemini API error: ${data['error'] ?? 'Unknown error'}');
    }

    // Validate nutrition section
    if (!data.containsKey('nutrition')) {
      throw GeminiException('Missing required field: nutrition');
    }

    final nutrition = data['nutrition'] as Map<String, dynamic>;

    // Check data source to determine validation mode
    final metadata = data['metadata'] as Map<String, dynamic>?;
    final dataSource = metadata?['data_source'] as String? ?? 'label';
    final isEstimation = dataSource == 'estimation';

    debugPrint('📋 Validation mode: $dataSource (estimation: $isEstimation)');

    // Check required macronutrients
    final requiredFields = ['carbohydrates_g', 'protein_g', 'fat_g'];
    for (final field in requiredFields) {
      if (!nutrition.containsKey(field) || nutrition[field] == null) {
        // For estimation mode, provide more helpful error message
        if (isEstimation) {
          throw GeminiException(
            '음식 인식에 실패했습니다. 음식이 선명하게 보이도록 다시 촬영해주세요.\n'
            '(필수 영양소 정보가 없습니다: $field)'
          );
        } else {
          throw GeminiException('Missing required nutrition field: $field');
        }
      }
    }

    // Validate ratio section
    if (!data.containsKey('ratio')) {
      throw GeminiException('Missing required field: ratio');
    }

    final ratio = data['ratio'] as Map<String, dynamic>;
    if (!ratio.containsKey('carb_ratio') ||
        !ratio.containsKey('protein_ratio') ||
        !ratio.containsKey('fat_ratio')) {
      throw GeminiException('Missing required ratio fields');
    }

    // Validate and normalize ratio sum
    int carbRatio = (ratio['carb_ratio'] as num).toInt();
    int proteinRatio = (ratio['protein_ratio'] as num).toInt();
    int fatRatio = (ratio['fat_ratio'] as num).toInt();
    int sum = carbRatio + proteinRatio + fatRatio;

    // If sum is not 100 (±5), normalize the ratios
    if ((sum - 100).abs() > AppConstants.ratioSumTolerance) {
      debugPrint('⚠️ Ratio sum is $sum, normalizing to 100...');

      // Calculate normalized ratios
      double total = carbRatio + proteinRatio + fatRatio.toDouble();
      carbRatio = ((carbRatio / total) * 100).round();
      proteinRatio = ((proteinRatio / total) * 100).round();
      fatRatio = 100 - carbRatio - proteinRatio; // Ensure sum is exactly 100

      // Update the ratio in data
      ratio['carb_ratio'] = carbRatio;
      ratio['protein_ratio'] = proteinRatio;
      ratio['fat_ratio'] = fatRatio;

      debugPrint('✓ Normalized ratios: $carbRatio:$proteinRatio:$fatRatio');
    }

    // Ensure raw_data exists
    if (!data.containsKey('raw_data')) {
      throw GeminiException('Missing required field: raw_data');
    }
  }

  /// Parse nutrition data from Gemini response
  NutritionData parseNutritionData(Map<String, dynamic> response) {
    final nutrition = response['nutrition'] as Map<String, dynamic>;

    return NutritionData(
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
      confidenceScores: _extractConfidenceScores(nutrition),
      rawData: response['raw_data'] as Map<String, dynamic>,
    );
  }

  /// Parse ratio data from Gemini response
  RatioData parseRatioData(Map<String, dynamic> response) {
    final ratio = response['ratio'] as Map<String, dynamic>;
    return RatioData.fromJson(ratio);
  }

  /// Extract confidence scores from nutrition data
  Map<String, double> _extractConfidenceScores(Map<String, dynamic> nutrition) {
    final scores = <String, double>{};
    nutrition.forEach((key, value) {
      if (key.endsWith('_confidence') && value is num) {
        final fieldName = key.replaceAll('_confidence', '');
        scores[fieldName] = value.toDouble();
      }
    });
    return scores;
  }

  /// Get healthier food alternatives from BigQuery
  ///
  /// Returns list of WHO-compliant alternative foods based on nutrition ratio
  /// Returns empty list if BigQuery is not configured or no alternatives found
  Future<List<Map<String, dynamic>>> getHealthierAlternatives({
    required String foodName,
    String? foodCategory,
    required int carbRatio,
    required int proteinRatio,
    required int fatRatio,
  }) async {
    if (_bigQueryService == null) {
      debugPrint('ℹ️ BigQuery not configured, skipping healthier alternatives search');
      return [];
    }

    try {
      debugPrint('🔍 Searching BigQuery for healthier alternatives...');
      final alternatives = await _bigQueryService!.getHealthierAlternatives(
        foodName: foodName,
        foodCategory: foodCategory,
        carbRatio: carbRatio,
        proteinRatio: proteinRatio,
        fatRatio: fatRatio,
      );

      if (alternatives.isEmpty) {
        debugPrint('ℹ️ No healthier alternatives found in BigQuery');
      } else {
        debugPrint('✅ Found ${alternatives.length} healthier alternatives');
      }

      return alternatives;
    } catch (e) {
      debugPrint('⚠️ BigQuery search failed: $e');
      return [];
    }
  }

  /// Generate personalized nutrition advice with BigQuery alternatives
  ///
  /// Combines user's health goal with USDA database recommendations
  Future<String> generateNutritionAdvice({
    required Map<String, dynamic> nutritionAnalysis,
    required UserProfile? userProfile,
  }) async {
    final adviceStart = DateTime.now();

    final ratio = nutritionAnalysis['ratio'] as Map<String, dynamic>;
    final carbRatio = (ratio['carb_ratio'] as num).toInt();
    final proteinRatio = (ratio['protein_ratio'] as num).toInt();
    final fatRatio = (ratio['fat_ratio'] as num).toInt();

    // Get healthier alternatives from BigQuery
    final classifiedData = nutritionAnalysis['classified_data'] as Map<String, dynamic>?;
    final foodName = classifiedData?['product_name'] as String? ?? '이 음식';
    final foodCategory = classifiedData?['food_category'] as String?;

    final bqStart = DateTime.now();
    final alternatives = await getHealthierAlternatives(
      foodName: foodName,
      foodCategory: foodCategory,
      carbRatio: carbRatio,
      proteinRatio: proteinRatio,
      fatRatio: fatRatio,
    );
    final bqDuration = DateTime.now().difference(bqStart).inMilliseconds;
    debugPrint('  ⏱️ BigQuery query: ${bqDuration}ms');

    // Build advice text
    final buffer = StringBuffer();

    // 1. User goal context (영양 비율은 RatioDisplay에서 이미 표시됨)
    if (userProfile != null && userProfile.healthGoal != null) {
      final goalLabels = {
        'lose': '체중 감량',
        'maintain': '체중 유지',
        'gain': '체중 증량',
        'muscle': '근육 증가',
        'health': '건강 유지',
      };
      final goalLabel = goalLabels[userProfile.healthGoal] ?? '건강 유지';
      final recommendedRatios = userProfile.recommendedMacroRatios;

      buffer.writeln('🎯 목표: $goalLabel');
      buffer.writeln('   권장 비율: 🥖탄${recommendedRatios['carbs']}% 🍗단${recommendedRatios['protein']}% 🥑지${recommendedRatios['fat']}%\n');
    } else {
      buffer.writeln('📌 WHO 권장: 🥖탄50% 🍗단30% 🥑지20%\n');
    }

    // 3. Healthier alternatives from BigQuery (if available)
    if (alternatives.isNotEmpty) {
      buffer.writeln('✅ 더 건강한 대안 (USDA 데이터):');
      for (final alt in alternatives.take(3)) {
        final altName = alt['description'] ?? 'Unknown';

        // Safe type conversion: BigQuery returns numbers as strings sometimes
        final altCarb = _parseIntSafely(alt['carb_ratio']) ?? 0;
        final altProtein = _parseIntSafely(alt['protein_ratio']) ?? 0;
        final altFat = _parseIntSafely(alt['fat_ratio']) ?? 0;
        final whoCompliant = alt['who_compliant'] == 'true' || alt['who_compliant'] == true;

        buffer.writeln('   • $altName');
        buffer.writeln('     🥖$altCarb% 🍗$altProtein% 🥑$altFat% ${whoCompliant ? "✅" : ""}');
      }
      buffer.writeln();
    }

    // 4. General advice
    if (carbRatio > 60) {
      buffer.writeln('⚠️ 탄수화물 비율이 높습니다.');
      buffer.writeln('   단백질이 풍부한 음식과 함께 드시는 것을 권장합니다.');
    } else if (proteinRatio < 20) {
      buffer.writeln('⚠️ 단백질 비율이 낮습니다.');
      buffer.writeln('   근육 건강을 위해 단백질 섭취를 늘리세요.');
    } else {
      buffer.writeln('✅ 균형잡힌 영양 비율입니다!');
    }

    final adviceDuration = DateTime.now().difference(adviceStart).inMilliseconds;
    debugPrint('  ⏱️ Total advice generation: ${adviceDuration}ms');

    return buffer.toString();
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
}

/// Custom exception for Gemini API errors
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => 'GeminiException: $message';
}
