import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';

/// Service for querying USDA nutrition data from BigQuery
///
/// Uses BigQuery REST API to search nutrition_foods table
/// populated by the Fivetran connector from USDA FoodData Central
class BigQueryService {
  final String projectId;
  final String datasetId;
  final String tableId;

  // Note: In production, use proper authentication (OAuth2, Service Account)
  // For hackathon demo, we'll use public access or API key
  final String? apiKey;

  // Service Account authentication
  AutoRefreshingAuthClient? _authClient;
  bool _authInitialized = false;

  BigQueryService({
    required this.projectId,
    this.datasetId = 'fivetran_usda',
    this.tableId = 'nutrition_foods',
    this.apiKey,
  }) {
    _initializeAuth();
  }

  /// Initialize Service Account authentication
  Future<void> _initializeAuth() async {
    if (_authInitialized) return;

    try {
      debugPrint('🔐 Initializing BigQuery Service Account authentication...');

      // Load Service Account JSON from assets
      final serviceAccountJson = await rootBundle.loadString(
        'android/app/src/main/assets/service-account.json',
      );

      // Parse credentials
      final accountCredentials = ServiceAccountCredentials.fromJson(
        jsonDecode(serviceAccountJson),
      );

      // Create authenticated client
      final scopes = ['https://www.googleapis.com/auth/bigquery.readonly'];
      _authClient = await clientViaServiceAccount(accountCredentials, scopes);

      _authInitialized = true;
      debugPrint('✅ BigQuery Service Account authentication successful!');
    } catch (e) {
      debugPrint('⚠️ BigQuery Service Account authentication failed: $e');
      debugPrint('   Falling back to unauthenticated mode (will fail)');
      _authClient = null;
      _authInitialized = true; // Mark as initialized to avoid retrying
    }
  }

  /// Search for foods by description (product name)
  ///
  /// Returns list of matching foods with nutrition data and ratios
  /// Limited to top 5 most relevant results
  Future<List<Map<String, dynamic>>> searchFoodsByName(String query) async {
    try {
      debugPrint('=== BIGQUERY SEARCH START ===');
      debugPrint('Query: $query');

      // Build SQL query
      final sql = '''
        SELECT
          food_id,
          fdc_id,
          description,
          food_category,
          energy_kcal,
          protein_g,
          fat_g,
          carbs_g,
          carb_ratio,
          protein_ratio,
          fat_ratio,
          who_compliant,
          carb_status,
          protein_status,
          fat_status
        FROM `$projectId.$datasetId.$tableId`
        WHERE LOWER(description) LIKE LOWER('%$query%')
        ORDER BY
          CASE
            WHEN who_compliant = TRUE THEN 0
            ELSE 1
          END,
          ABS(carb_ratio - 50) + ABS(protein_ratio - 30) + ABS(fat_ratio - 20) ASC
        LIMIT 5
      ''';

      debugPrint('SQL: $sql');

      // Call BigQuery REST API
      final response = await _executeBigQueryQuery(sql);

      if (response == null || response.isEmpty) {
        debugPrint('No results found');
        return [];
      }

      debugPrint('Found ${response.length} results');
      return response;
    } catch (e) {
      debugPrint('BigQuery search error: $e');
      return [];
    }
  }

  /// Find similar foods by nutrition ratio
  ///
  /// Given carb/protein/fat ratios, find foods with similar macronutrient distribution
  /// Useful for finding healthier alternatives
  Future<List<Map<String, dynamic>>> findSimilarFoodsByRatio({
    required int carbRatio,
    required int proteinRatio,
    required int fatRatio,
    String? category,
  }) async {
    try {
      debugPrint('=== BIGQUERY SIMILARITY SEARCH START ===');
      debugPrint('Target ratio: 🥖$carbRatio 🍗$proteinRatio 🥑$fatRatio');

      // Calculate similarity score: lower is better
      // We want foods with similar ratios but WHO compliant
      final categoryFilter = category != null
          ? "AND LOWER(food_category) LIKE LOWER('%$category%')"
          : '';

      final sql = '''
        SELECT
          food_id,
          fdc_id,
          description,
          food_category,
          energy_kcal,
          protein_g,
          fat_g,
          carbs_g,
          carb_ratio,
          protein_ratio,
          fat_ratio,
          who_compliant,
          carb_status,
          protein_status,
          fat_status,
          (ABS(carb_ratio - $carbRatio) +
           ABS(protein_ratio - $proteinRatio) +
           ABS(fat_ratio - $fatRatio)) AS similarity_score
        FROM `$projectId.$datasetId.$tableId`
        WHERE who_compliant = TRUE
        $categoryFilter
        ORDER BY similarity_score ASC
        LIMIT 5
      ''';

      debugPrint('SQL: $sql');

      final response = await _executeBigQueryQuery(sql);

      if (response == null || response.isEmpty) {
        debugPrint('No similar foods found');
        return [];
      }

      debugPrint('Found ${response.length} similar WHO-compliant foods');
      return response;
    } catch (e) {
      debugPrint('BigQuery similarity search error: $e');
      return [];
    }
  }

  /// Get healthier alternatives for a given food
  ///
  /// Finds foods in the same/similar category with better WHO compliance
  Future<List<Map<String, dynamic>>> getHealthierAlternatives({
    required String foodName,
    String? foodCategory,
    required int carbRatio,
    required int proteinRatio,
    required int fatRatio,
  }) async {
    try {
      debugPrint('=== BIGQUERY HEALTHIER ALTERNATIVES SEARCH ===');
      debugPrint('Original food: $foodName (category: $foodCategory)');

      // Map Korean food names to USDA categories
      final categoryKeywords = _extractCategoryKeywords(foodName, foodCategory);
      debugPrint('Category keywords: $categoryKeywords');

      // Strategy: Find WHO-compliant foods that are:
      // 1. In similar category (if possible)
      // 2. Lower in carbs (if current food is high-carb)
      // 3. Higher in protein (if current food is low-protein)

      final carbStatus = carbRatio > 60 ? 'high' : (carbRatio < 40 ? 'low' : 'normal');
      final proteinStatus = proteinRatio < 20 ? 'low' : (proteinRatio > 40 ? 'high' : 'normal');

      debugPrint('Current status: carb=$carbStatus, protein=$proteinStatus');

      // Build category filter
      String categoryFilter = '';
      if (categoryKeywords.isNotEmpty) {
        final conditions = categoryKeywords.map((kw) =>
          "LOWER(description) LIKE '%$kw%' OR LOWER(food_category) LIKE '%$kw%'"
        ).join(' OR ');
        categoryFilter = 'AND ($conditions)';
      }

      final sql = '''
        SELECT
          food_id,
          fdc_id,
          description,
          food_category,
          energy_kcal,
          protein_g,
          fat_g,
          carbs_g,
          carb_ratio,
          protein_ratio,
          fat_ratio,
          who_compliant,
          carb_status,
          protein_status,
          fat_status,
          (ABS(carb_ratio - 50) + ABS(protein_ratio - 30) + ABS(fat_ratio - 20)) AS who_distance
        FROM `$projectId.$datasetId.$tableId`
        WHERE who_compliant = TRUE
        ${carbStatus == 'high' ? 'AND carb_ratio < $carbRatio' : ''}
        ${proteinStatus == 'low' ? 'AND protein_ratio > $proteinRatio' : ''}
        $categoryFilter
        ORDER BY
          who_distance ASC,
          energy_kcal ASC
        LIMIT 5
      ''';

      debugPrint('SQL: $sql');

      final response = await _executeBigQueryQuery(sql);

      if (response == null || response.isEmpty) {
        debugPrint('No category-specific alternatives found, trying generic WHO-compliant foods...');

        // Fallback: No category filter
        final fallbackSql = '''
          SELECT
            food_id,
            fdc_id,
            description,
            food_category,
            energy_kcal,
            protein_g,
            fat_g,
            carbs_g,
            carb_ratio,
            protein_ratio,
            fat_ratio,
            who_compliant,
            carb_status,
            protein_status,
            fat_status
          FROM `$projectId.$datasetId.$tableId`
          WHERE who_compliant = TRUE
          ${carbStatus == 'high' ? 'AND carb_ratio < $carbRatio' : ''}
          ${proteinStatus == 'low' ? 'AND protein_ratio > $proteinRatio' : ''}
          ORDER BY
            ABS(carb_ratio - 50) + ABS(protein_ratio - 30) + ABS(fat_ratio - 20) ASC
          LIMIT 5
        ''';

        final fallbackResponse = await _executeBigQueryQuery(fallbackSql);
        if (fallbackResponse == null || fallbackResponse.isEmpty) {
          debugPrint('No healthier alternatives found');
          return [];
        }

        debugPrint('Found ${fallbackResponse.length} generic healthier alternatives');
        return fallbackResponse;
      }

      debugPrint('Found ${response.length} healthier alternatives');
      return response;
    } catch (e) {
      debugPrint('BigQuery healthier alternatives search error: $e');
      return [];
    }
  }

  /// Extract USDA category keywords from Korean food name
  ///
  /// Maps Korean food names to English USDA category terms
  List<String> _extractCategoryKeywords(String foodName, String? foodCategory) {
    final keywords = <String>[];
    final lowerFoodName = foodName.toLowerCase();
    final lowerCategory = foodCategory?.toLowerCase() ?? '';

    // Korean to USDA category mapping
    final categoryMap = {
      // 고기류 (Meat)
      '삼겹살': ['pork', 'bacon'],
      '갈비': ['pork', 'beef', 'rib'],
      '불고기': ['beef'],
      '치킨': ['chicken', 'poultry'],
      '닭': ['chicken', 'poultry'],
      '삼계탕': ['chicken', 'poultry', 'soup'],
      '감자탕': ['pork', 'soup'],

      // 밥/곡류 (Grains)
      '밥': ['rice', 'grain'],
      '비빔밥': ['rice', 'mixed', 'vegetable'],
      '볶음밥': ['rice', 'fried'],
      '김밥': ['rice', 'seaweed'],
      '회덮밥': ['rice', 'fish', 'raw'],

      // 면류 (Noodles)
      '라면': ['noodle', 'ramen'],
      '짜장면': ['noodle', 'bean'],
      '짬뽕': ['noodle', 'seafood'],
      '냉면': ['noodle', 'buckwheat'],

      // 국/찌개/탕 (Soup/Stew)
      '김치찌개': ['kimchi', 'soup', 'stew'],
      '된장찌개': ['soybean', 'soup', 'miso'],
      '부대찌개': ['soup', 'stew'],
      '순두부찌개': ['tofu', 'soup'],
      '순대국밥': ['soup', 'rice'],

      // 분식 (Snacks)
      '떡볶이': ['rice cake'],
      '순대': ['sausage'],
      '튀김': ['fried', 'tempura'],

      // 반찬 (Side dishes)
      '깍두기': ['radish', 'kimchi'],
      '도토리묵': ['acorn', 'jelly'],
      '김치': ['kimchi', 'cabbage'],

      // 디저트 (Desserts)
      '인절미': ['rice cake', 'dessert'],
      '화채': ['fruit', 'punch', 'beverage'],
    };

    // Check exact matches
    for (final entry in categoryMap.entries) {
      if (lowerFoodName.contains(entry.key) || lowerCategory.contains(entry.key)) {
        keywords.addAll(entry.value);
      }
    }

    // Generic category detection
    if (lowerCategory.contains('고기') || lowerCategory.contains('육류')) {
      keywords.addAll(['meat', 'protein']);
    } else if (lowerCategory.contains('밥') || lowerCategory.contains('곡류')) {
      keywords.addAll(['rice', 'grain']);
    } else if (lowerCategory.contains('면')) {
      keywords.add('noodle');
    } else if (lowerCategory.contains('국') || lowerCategory.contains('찌개') || lowerCategory.contains('탕')) {
      keywords.add('soup');
    } else if (lowerCategory.contains('디저트') || lowerCategory.contains('떡')) {
      keywords.addAll(['dessert', 'sweet']);
    }

    // Remove duplicates and return
    return keywords.toSet().toList();
  }

  /// Execute BigQuery SQL query via REST API
  ///
  /// Returns list of row data as Map
  Future<List<Map<String, dynamic>>?> _executeBigQueryQuery(String sql) async {
    try {
      // Ensure authentication is initialized
      if (!_authInitialized) {
        await _initializeAuth();
      }

      // BigQuery API endpoint
      final url = Uri.parse(
        'https://bigquery.googleapis.com/bigquery/v2/projects/$projectId/queries'
      );

      // Request body
      final body = jsonEncode({
        'query': sql,
        'useLegacySql': false,
        'timeoutMs': 10000,
      });

      debugPrint('Calling BigQuery API with Service Account auth...');

      http.Response response;

      // Use authenticated client if available
      if (_authClient != null) {
        // Use googleapis_auth client
        response = await _authClient!.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('BigQuery query timeout');
          },
        );
      } else {
        // Fallback to unauthenticated (will likely fail)
        debugPrint('⚠️ No auth client available, using unauthenticated request');
        final headers = {
          'Content-Type': 'application/json',
          if (apiKey != null) 'X-Goog-Api-Key': apiKey!,
        };

        response = await http.post(
          url,
          headers: headers,
          body: body,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('BigQuery query timeout');
          },
        );
      }

      debugPrint('BigQuery response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('BigQuery error: ${response.body}');
        return null;
      }

      // Parse response
      final jsonResponse = jsonDecode(response.body);

      if (!jsonResponse.containsKey('rows') || jsonResponse['rows'] == null) {
        debugPrint('No rows in response');
        return [];
      }

      // Extract schema
      final schema = jsonResponse['schema']['fields'] as List;
      final rows = jsonResponse['rows'] as List;

      // Convert rows to Maps
      final results = <Map<String, dynamic>>[];
      for (final row in rows) {
        final rowData = <String, dynamic>{};
        final values = row['f'] as List;

        for (var i = 0; i < schema.length; i++) {
          final fieldName = schema[i]['name'];
          final fieldValue = values[i]['v'];
          rowData[fieldName] = fieldValue;
        }

        results.add(rowData);
      }

      debugPrint('Parsed ${results.length} rows');
      return results;
    } catch (e) {
      debugPrint('BigQuery API call failed: $e');
      return null;
    }
  }
}

/// Custom exception for BigQuery errors
class BigQueryException implements Exception {
  final String message;
  BigQueryException(this.message);

  @override
  String toString() => 'BigQueryException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
