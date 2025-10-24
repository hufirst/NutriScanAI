import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

/// SQLite database service for TanDanGenie
///
/// Manages local storage of scan results, validation reports, Fivetran queue,
/// and user settings. Implements the Raw/Classified data separation strategy
/// with confidence-based filtering.
class StorageService {
  static Database? _database;
  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create all tables on first installation
  Future<void> _onCreate(Database db, int version) async {
    // Create scan_results table
    await db.execute('''
      CREATE TABLE scan_results (
        -- Primary Key
        scan_id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,

        -- [CERTAIN DATA] - 100% 확실한 데이터
        carb_ratio INTEGER NOT NULL CHECK(carb_ratio >= 0 AND carb_ratio <= 100),
        protein_ratio INTEGER NOT NULL CHECK(protein_ratio >= 0 AND protein_ratio <= 100),
        fat_ratio INTEGER NOT NULL CHECK(fat_ratio >= 0 AND fat_ratio <= 100),
        image_url TEXT NOT NULL,

        -- [CLASSIFIED DATA] - 신뢰도 ≥0.85인 데이터
        -- Product Info
        product_name TEXT,
        product_name_confidence REAL CHECK(product_name_confidence >= 0 AND product_name_confidence <= 1),
        manufacturer TEXT,
        manufacturer_confidence REAL,
        barcode TEXT,
        barcode_confidence REAL,
        barcode_verified INTEGER DEFAULT 0,
        food_category TEXT,
        category_confidence REAL,

        -- Nutrition Facts
        serving_size TEXT,
        serving_size_confidence REAL,
        calories INTEGER,
        calories_confidence REAL,
        carbohydrates_g REAL,
        carbohydrates_confidence REAL,
        protein_g REAL,
        protein_confidence REAL,
        fat_g REAL,
        fat_confidence REAL,
        sodium_mg INTEGER,
        sodium_confidence REAL,
        sugars_g REAL,
        sugars_confidence REAL,
        saturated_fat_g REAL,
        saturated_fat_confidence REAL,
        trans_fat_g REAL,
        trans_fat_confidence REAL,
        cholesterol_mg INTEGER,
        cholesterol_confidence REAL,
        dietary_fiber_g REAL,
        dietary_fiber_confidence REAL,

        -- [RAW DATA] - OCR 원본 (JSON)
        ocr_full_text TEXT,
        ocr_json TEXT,
        nutrition_raw TEXT,
        product_info_raw TEXT,
        ingredients_raw TEXT,

        -- [METADATA]
        image_quality TEXT CHECK(image_quality IN ('good', 'medium', 'poor')),
        language_detected TEXT DEFAULT 'ko',
        validation_status TEXT NOT NULL CHECK(validation_status IN ('passed', 'warning', 'failed')),
        app_version TEXT,
        platform TEXT CHECK(platform IN ('android', 'ios')),
        device_model TEXT,

        -- Fivetran Sync
        fivetran_synced INTEGER DEFAULT 0,
        fivetran_synced_at INTEGER,
        fivetran_retry_count INTEGER DEFAULT 0,

        -- Nutrition Advice
        nutrition_advice TEXT,

        -- Constraint: ratio sum must be approximately 100 (allow ±1 for rounding)
        CONSTRAINT ratio_sum CHECK(carb_ratio + protein_ratio + fat_ratio >= 99 AND carb_ratio + protein_ratio + fat_ratio <= 101)
      )
    ''');

    // Create indexes for scan_results
    await db.execute(
        'CREATE INDEX idx_timestamp ON scan_results(timestamp DESC)');
    await db.execute(
        'CREATE INDEX idx_fivetran_synced ON scan_results(fivetran_synced) WHERE fivetran_synced = 0');
    await db.execute(
        'CREATE INDEX idx_validation_status ON scan_results(validation_status)');
    await db.execute(
        'CREATE INDEX idx_food_category ON scan_results(food_category) WHERE food_category IS NOT NULL');

    // Create validation_reports table
    await db.execute('''
      CREATE TABLE validation_reports (
        report_id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,

        -- Level 1: Required Fields
        level1_pass INTEGER NOT NULL,
        level1_missing_fields TEXT,

        -- Level 2: Value Validation
        level2_warnings TEXT,

        -- Level 3: Logical Consistency
        level3_ratio_sum_valid INTEGER,
        level3_calorie_diff_percent REAL,

        -- Level 4: Anomaly Detection
        level4_anomalies TEXT,

        -- Level 5: Confidence Filtering
        level5_low_confidence_count INTEGER,
        level5_details TEXT,

        FOREIGN KEY (scan_id) REFERENCES scan_results(scan_id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_validation_scan ON validation_reports(scan_id)');

    // Create fivetran_queue table
    await db.execute('''
      CREATE TABLE fivetran_queue (
        queue_id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        next_retry_at INTEGER,

        FOREIGN KEY (scan_id) REFERENCES scan_results(scan_id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_queue_retry ON fivetran_queue(next_retry_at) WHERE retry_count < 3');

    // Create user_settings table
    await db.execute('''
      CREATE TABLE user_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Insert default settings
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('user_settings',
        {'setting_key': 'target_carb_ratio', 'setting_value': '40', 'updated_at': now});
    await db.insert('user_settings', {
      'setting_key': 'target_protein_ratio',
      'setting_value': '30',
      'updated_at': now
    });
    await db.insert('user_settings',
        {'setting_key': 'target_fat_ratio', 'setting_value': '30', 'updated_at': now});
    await db.insert('user_settings', {
      'setting_key': 'notifications_enabled',
      'setting_value': '1',
      'updated_at': now
    });
    await db.insert('user_settings', {
      'setting_key': 'auto_fivetran_sync',
      'setting_value': '1',
      'updated_at': now
    });

    // Create daily_intake table
    await db.execute('''
      CREATE TABLE daily_intake (
        -- Primary Key: Date in YYYY-MM-DD format
        date TEXT PRIMARY KEY,

        -- Aggregated Totals
        total_calories INTEGER NOT NULL DEFAULT 0,
        carb_calories INTEGER NOT NULL DEFAULT 0,
        protein_calories INTEGER NOT NULL DEFAULT 0,
        fat_calories INTEGER NOT NULL DEFAULT 0,

        -- Macronutrient Totals (in grams)
        total_carb_g REAL NOT NULL DEFAULT 0.0,
        total_protein_g REAL NOT NULL DEFAULT 0.0,
        total_fat_g REAL NOT NULL DEFAULT 0.0,

        -- Data Quality
        has_estimated_data INTEGER DEFAULT 0,
        scan_count INTEGER NOT NULL DEFAULT 0,

        -- Metadata
        updated_at INTEGER NOT NULL,

        -- Constraints
        CHECK(total_calories >= 0),
        CHECK(carb_calories >= 0),
        CHECK(protein_calories >= 0),
        CHECK(fat_calories >= 0),
        CHECK(scan_count >= 0)
      )
    ''');

    // Create index for date-based queries
    await db.execute(
        'CREATE INDEX idx_daily_intake_date ON daily_intake(date DESC)');
  }

  /// Handle database schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrate from version 1 to 2: Relax ratio sum constraint
    if (oldVersion < 2) {
      // SQLite doesn't support modifying constraints directly
      // We need to recreate the table with the new constraint

      // Step 1: Rename old table
      await db.execute('ALTER TABLE scan_results RENAME TO scan_results_old');

      // Step 2: Create new table with updated constraint
      await db.execute('''
        CREATE TABLE scan_results (
          -- Primary Key
          scan_id TEXT PRIMARY KEY,
          timestamp INTEGER NOT NULL,

          -- [CERTAIN DATA] - 100% 확실한 데이터
          carb_ratio INTEGER NOT NULL CHECK(carb_ratio >= 0 AND carb_ratio <= 100),
          protein_ratio INTEGER NOT NULL CHECK(protein_ratio >= 0 AND protein_ratio <= 100),
          fat_ratio INTEGER NOT NULL CHECK(fat_ratio >= 0 AND fat_ratio <= 100),
          image_url TEXT NOT NULL,

          -- [CLASSIFIED DATA] - 신뢰도 ≥0.85인 데이터
          product_name TEXT,
          product_name_confidence REAL CHECK(product_name_confidence >= 0 AND product_name_confidence <= 1),
          manufacturer TEXT,
          manufacturer_confidence REAL,
          barcode TEXT,
          barcode_confidence REAL,
          barcode_verified INTEGER DEFAULT 0,
          food_category TEXT,
          category_confidence REAL,

          -- Nutrition Facts
          serving_size TEXT,
          serving_size_confidence REAL,
          calories INTEGER,
          calories_confidence REAL,
          carbohydrates_g REAL,
          carbohydrates_confidence REAL,
          protein_g REAL,
          protein_confidence REAL,
          fat_g REAL,
          fat_confidence REAL,
          sodium_mg INTEGER,
          sodium_confidence REAL,
          sugars_g REAL,
          sugars_confidence REAL,
          saturated_fat_g REAL,
          saturated_fat_confidence REAL,
          trans_fat_g REAL,
          trans_fat_confidence REAL,
          cholesterol_mg INTEGER,
          cholesterol_confidence REAL,
          dietary_fiber_g REAL,
          dietary_fiber_confidence REAL,

          -- [RAW DATA] - OCR 원본 (JSON)
          ocr_full_text TEXT,
          ocr_json TEXT,
          nutrition_raw TEXT,
          product_info_raw TEXT,
          ingredients_raw TEXT,

          -- [METADATA]
          image_quality TEXT CHECK(image_quality IN ('good', 'medium', 'poor')),
          language_detected TEXT DEFAULT 'ko',
          validation_status TEXT NOT NULL CHECK(validation_status IN ('passed', 'warning', 'failed')),
          app_version TEXT,
          platform TEXT CHECK(platform IN ('android', 'ios')),
          device_model TEXT,

          -- Fivetran Sync
          fivetran_synced INTEGER DEFAULT 0,
          fivetran_synced_at INTEGER,
          fivetran_retry_count INTEGER DEFAULT 0,

          -- Constraint: ratio sum must be approximately 100 (allow ±1 for rounding)
          CONSTRAINT ratio_sum CHECK(carb_ratio + protein_ratio + fat_ratio >= 99 AND carb_ratio + protein_ratio + fat_ratio <= 101)
        )
      ''');

      // Step 3: Copy data from old table
      await db.execute('''
        INSERT INTO scan_results
        SELECT * FROM scan_results_old
      ''');

      // Step 4: Drop old table
      await db.execute('DROP TABLE scan_results_old');

      // Step 5: Recreate indexes
      await db.execute(
          'CREATE INDEX idx_timestamp ON scan_results(timestamp DESC)');
      await db.execute(
          'CREATE INDEX idx_fivetran_synced ON scan_results(fivetran_synced) WHERE fivetran_synced = 0');
      await db.execute(
          'CREATE INDEX idx_validation_status ON scan_results(validation_status)');
      await db.execute(
          'CREATE INDEX idx_food_category ON scan_results(food_category) WHERE food_category IS NOT NULL');
    }

    // Migrate from version 2 to 3: Add nutrition_advice column
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE scan_results ADD COLUMN nutrition_advice TEXT
      ''');
    }

    // Migrate from version 3 to 4: Add daily_intake table
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE daily_intake (
          -- Primary Key: Date in YYYY-MM-DD format
          date TEXT PRIMARY KEY,

          -- Aggregated Totals
          total_calories INTEGER NOT NULL DEFAULT 0,
          carb_calories INTEGER NOT NULL DEFAULT 0,
          protein_calories INTEGER NOT NULL DEFAULT 0,
          fat_calories INTEGER NOT NULL DEFAULT 0,

          -- Macronutrient Totals (in grams)
          total_carb_g REAL NOT NULL DEFAULT 0.0,
          total_protein_g REAL NOT NULL DEFAULT 0.0,
          total_fat_g REAL NOT NULL DEFAULT 0.0,

          -- Data Quality
          has_estimated_data INTEGER DEFAULT 0,
          scan_count INTEGER NOT NULL DEFAULT 0,

          -- Metadata
          updated_at INTEGER NOT NULL,

          -- Constraints
          CHECK(total_calories >= 0),
          CHECK(carb_calories >= 0),
          CHECK(protein_calories >= 0),
          CHECK(fat_calories >= 0),
          CHECK(scan_count >= 0)
        )
      ''');

      await db.execute(
          'CREATE INDEX idx_daily_intake_date ON daily_intake(date DESC)');
    }
  }

  // ============================================================================
  // CRUD Operations: scan_results
  // ============================================================================

  /// Insert a new scan result
  Future<int> insertScanResult(Map<String, dynamic> scanData) async {
    final db = await database;
    return await db.insert('scan_results', scanData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get scan result by ID
  Future<Map<String, dynamic>?> getScanResultById(String scanId) async {
    final db = await database;
    final results = await db.query(
      'scan_results',
      where: 'scan_id = ?',
      whereArgs: [scanId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get recent scan results (for history)
  Future<List<Map<String, dynamic>>> getRecentScanResults(
      {int limit = 100}) async {
    final db = await database;
    return await db.query(
      'scan_results',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// Get all scan results (alias for getRecentScanResults)
  Future<List<Map<String, dynamic>>> getAllScanResults(
      {int limit = 100}) async {
    return await getRecentScanResults(limit: limit);
  }

  /// Delete all scan results
  Future<int> deleteAllScanResults() async {
    final db = await database;
    return await db.delete('scan_results');
  }

  /// Get scan results by validation status
  Future<List<Map<String, dynamic>>> getScanResultsByStatus(
      String status) async {
    final db = await database;
    return await db.query(
      'scan_results',
      where: 'validation_status = ?',
      whereArgs: [status],
      orderBy: 'timestamp DESC',
    );
  }

  /// Get scan results by food category
  Future<List<Map<String, dynamic>>> getScanResultsByCategory(
      String category) async {
    final db = await database;
    return await db.query(
      'scan_results',
      where: 'food_category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
  }

  /// Update scan result
  Future<int> updateScanResult(
      String scanId, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'scan_results',
      data,
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  /// Delete scan result
  Future<int> deleteScanResult(String scanId) async {
    final db = await database;
    return await db.delete(
      'scan_results',
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  /// Delete old scan results (keep recent N records)
  Future<int> cleanupOldScans({int keepCount = 1000}) async {
    final db = await database;
    // Delete records older than the Nth most recent record
    return await db.rawDelete('''
      DELETE FROM scan_results
      WHERE scan_id NOT IN (
        SELECT scan_id FROM scan_results
        ORDER BY timestamp DESC
        LIMIT ?
      )
    ''', [keepCount]);
  }

  // ============================================================================
  // CRUD Operations: validation_reports
  // ============================================================================

  /// Insert validation report
  Future<int> insertValidationReport(Map<String, dynamic> reportData) async {
    final db = await database;
    return await db.insert('validation_reports', reportData);
  }

  /// Get validation report by scan ID
  Future<Map<String, dynamic>?> getValidationReportByScanId(
      String scanId) async {
    final db = await database;
    final results = await db.query(
      'validation_reports',
      where: 'scan_id = ?',
      whereArgs: [scanId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ============================================================================
  // CRUD Operations: fivetran_queue
  // ============================================================================

  /// Insert item into Fivetran queue
  Future<int> insertFivetranQueue(Map<String, dynamic> queueData) async {
    final db = await database;
    return await db.insert('fivetran_queue', queueData);
  }

  /// Get pending Fivetran queue items (ready for retry)
  Future<List<Map<String, dynamic>>> getPendingFivetranQueue() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return await db.query(
      'fivetran_queue',
      where: 'retry_count < 3 AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [now],
      orderBy: 'created_at ASC',
    );
  }

  /// Update Fivetran queue item
  Future<int> updateFivetranQueue(
      String queueId, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'fivetran_queue',
      data,
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
  }

  /// Delete Fivetran queue item (after successful sync)
  Future<int> deleteFivetranQueue(String queueId) async {
    final db = await database;
    return await db.delete(
      'fivetran_queue',
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
  }

  // ============================================================================
  // CRUD Operations: user_settings
  // ============================================================================

  /// Get setting value by key
  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'user_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return results.isNotEmpty ? results.first['setting_value'] as String : null;
  }

  /// Set setting value
  Future<int> setSetting(String key, String value) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return await db.insert(
      'user_settings',
      {'setting_key': key, 'setting_value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all settings
  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('user_settings');
    return Map.fromEntries(
      results.map((row) =>
          MapEntry(row['setting_key'] as String, row['setting_value'] as String)),
    );
  }

  // ============================================================================
  // Statistics & Analytics
  // ============================================================================

  /// Get total scan count
  Future<int> getTotalScanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scan_results');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count by validation status
  Future<Map<String, int>> getScanCountByStatus() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT validation_status, COUNT(*) as count
      FROM scan_results
      GROUP BY validation_status
    ''');

    return Map.fromEntries(
      results.map((row) =>
          MapEntry(row['validation_status'] as String, row['count'] as int)),
    );
  }

  /// Get count by food category
  Future<Map<String, int>> getScanCountByCategory() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT food_category, COUNT(*) as count
      FROM scan_results
      WHERE food_category IS NOT NULL
      GROUP BY food_category
      ORDER BY count DESC
    ''');

    return Map.fromEntries(
      results.map((row) =>
          MapEntry(row['food_category'] as String, row['count'] as int)),
    );
  }

  // ============================================================================
  // Database Utilities
  // ============================================================================

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete database (for testing or reset)
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
