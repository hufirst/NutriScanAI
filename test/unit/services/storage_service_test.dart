import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tandangenie/services/storage_service.dart';

void main() {
  late StorageService storageService;

  setUpAll(() {
    // Initialize FFI for desktop testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storageService = StorageService();
    // Clean up before each test
    try {
      await storageService.deleteDatabase();
    } catch (e) {
      // Ignore if database doesn't exist
    }
  });

  tearDown(() async {
    await storageService.close();
  });

  group('Database Initialization', () {
    test('should create database with all tables', () async {
      final db = await storageService.database;
      expect(db, isNotNull);

      // Check if tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();
      expect(tableNames, contains('scan_results'));
      expect(tableNames, contains('validation_reports'));
      expect(tableNames, contains('fivetran_queue'));
      expect(tableNames, contains('user_settings'));
    });

    test('should insert default user settings', () async {
      final settings = await storageService.getAllSettings();
      expect(settings['target_carb_ratio'], '40');
      expect(settings['target_protein_ratio'], '30');
      expect(settings['target_fat_ratio'], '30');
      expect(settings['notifications_enabled'], '1');
      expect(settings['auto_fivetran_sync'], '1');
    });
  });

  group('scan_results CRUD', () {
    test('should insert and retrieve scan result', () async {
      final scanData = {
        'scan_id': 'test-scan-001',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/path/to/image.jpg',
        'validation_status': 'passed',
      };

      await storageService.insertScanResult(scanData);
      final retrieved = await storageService.getScanResultById('test-scan-001');

      expect(retrieved, isNotNull);
      expect(retrieved!['scan_id'], 'test-scan-001');
      expect(retrieved['carb_ratio'], 50);
      expect(retrieved['protein_ratio'], 30);
      expect(retrieved['fat_ratio'], 20);
    });

    test('should enforce ratio sum constraint', () async {
      final invalidScanData = {
        'scan_id': 'test-scan-invalid',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 30, // Sum = 110, should fail
        'image_url': '/path/to/image.jpg',
        'validation_status': 'passed',
      };

      expect(
        () => storageService.insertScanResult(invalidScanData),
        throwsA(isA<Exception>()),
      );
    });

    test('should get recent scan results ordered by timestamp', () async {
      // Insert 3 scans with different timestamps
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await storageService.insertScanResult({
        'scan_id': 'scan-1',
        'timestamp': now - 200,
        'carb_ratio': 40,
        'protein_ratio': 30,
        'fat_ratio': 30,
        'image_url': '/image1.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-2',
        'timestamp': now - 100,
        'carb_ratio': 50,
        'protein_ratio': 25,
        'fat_ratio': 25,
        'image_url': '/image2.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-3',
        'timestamp': now,
        'carb_ratio': 60,
        'protein_ratio': 20,
        'fat_ratio': 20,
        'image_url': '/image3.jpg',
        'validation_status': 'passed',
      });

      final recent = await storageService.getRecentScanResults(limit: 10);
      expect(recent.length, 3);
      expect(recent[0]['scan_id'], 'scan-3'); // Most recent first
      expect(recent[1]['scan_id'], 'scan-2');
      expect(recent[2]['scan_id'], 'scan-1');
    });

    test('should filter scan results by validation status', () async {
      await storageService.insertScanResult({
        'scan_id': 'scan-passed',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-failed',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 40,
        'protein_ratio': 30,
        'fat_ratio': 30,
        'image_url': '/image.jpg',
        'validation_status': 'failed',
      });

      final passed =
          await storageService.getScanResultsByStatus('passed');
      final failed =
          await storageService.getScanResultsByStatus('failed');

      expect(passed.length, 1);
      expect(passed[0]['scan_id'], 'scan-passed');
      expect(failed.length, 1);
      expect(failed[0]['scan_id'], 'scan-failed');
    });

    test('should update scan result', () async {
      await storageService.insertScanResult({
        'scan_id': 'scan-update',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });

      await storageService.updateScanResult('scan-update', {
        'product_name': 'Updated Product',
        'product_name_confidence': 0.95,
      });

      final updated = await storageService.getScanResultById('scan-update');
      expect(updated!['product_name'], 'Updated Product');
      expect(updated['product_name_confidence'], 0.95);
    });

    test('should delete scan result', () async {
      await storageService.insertScanResult({
        'scan_id': 'scan-delete',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });

      await storageService.deleteScanResult('scan-delete');
      final deleted = await storageService.getScanResultById('scan-delete');
      expect(deleted, isNull);
    });
  });

  group('validation_reports', () {
    test('should insert and retrieve validation report', () async {
      // First insert a scan result
      await storageService.insertScanResult({
        'scan_id': 'scan-with-report',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'warning',
      });

      // Insert validation report
      await storageService.insertValidationReport({
        'report_id': 'report-001',
        'scan_id': 'scan-with-report',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'level1_pass': 1,
        'level1_missing_fields': null,
        'level2_warnings': '["Low confidence on product name"]',
        'level3_ratio_sum_valid': 1,
        'level3_calorie_diff_percent': 2.5,
        'level4_anomalies': null,
        'level5_low_confidence_count': 1,
        'level5_details': '{"product_name": 0.8}',
      });

      final report =
          await storageService.getValidationReportByScanId('scan-with-report');
      expect(report, isNotNull);
      expect(report!['scan_id'], 'scan-with-report');
      expect(report['level1_pass'], 1);
    });
  });

  group('fivetran_queue', () {
    test('should insert and retrieve pending queue items', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await storageService.insertFivetranQueue({
        'queue_id': 'queue-001',
        'scan_id': 'scan-001',
        'payload': '{"data": "test"}',
        'created_at': now,
        'retry_count': 0,
        'next_retry_at': now + 60,
      });

      final pending = await storageService.getPendingFivetranQueue();
      expect(pending.length, 0); // Not ready yet (next_retry_at is in future)
    });

    test('should update queue item retry count', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await storageService.insertFivetranQueue({
        'queue_id': 'queue-retry',
        'scan_id': 'scan-001',
        'payload': '{"data": "test"}',
        'created_at': now,
        'retry_count': 0,
      });

      await storageService.updateFivetranQueue('queue-retry', {
        'retry_count': 1,
        'last_error': 'Connection timeout',
        'next_retry_at': now + 120,
      });

      final db = await storageService.database;
      final result = await db.query('fivetran_queue',
          where: 'queue_id = ?', whereArgs: ['queue-retry']);

      expect(result[0]['retry_count'], 1);
      expect(result[0]['last_error'], 'Connection timeout');
    });
  });

  group('user_settings', () {
    test('should get and set settings', () async {
      await storageService.setSetting('test_key', 'test_value');
      final value = await storageService.getSetting('test_key');
      expect(value, 'test_value');
    });

    test('should update existing setting', () async {
      await storageService.setSetting('update_key', 'initial');
      await storageService.setSetting('update_key', 'updated');
      final value = await storageService.getSetting('update_key');
      expect(value, 'updated');
    });
  });

  group('Statistics', () {
    test('should get total scan count', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await storageService.insertScanResult({
        'scan_id': 'scan-1',
        'timestamp': now,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-2',
        'timestamp': now,
        'carb_ratio': 40,
        'protein_ratio': 30,
        'fat_ratio': 30,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });

      final count = await storageService.getTotalScanCount();
      expect(count, 2);
    });

    test('should get count by validation status', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await storageService.insertScanResult({
        'scan_id': 'scan-1',
        'timestamp': now,
        'carb_ratio': 50,
        'protein_ratio': 30,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-2',
        'timestamp': now,
        'carb_ratio': 40,
        'protein_ratio': 30,
        'fat_ratio': 30,
        'image_url': '/image.jpg',
        'validation_status': 'passed',
      });
      await storageService.insertScanResult({
        'scan_id': 'scan-3',
        'timestamp': now,
        'carb_ratio': 60,
        'protein_ratio': 20,
        'fat_ratio': 20,
        'image_url': '/image.jpg',
        'validation_status': 'failed',
      });

      final counts = await storageService.getScanCountByStatus();
      expect(counts['passed'], 2);
      expect(counts['failed'], 1);
    });
  });
}
