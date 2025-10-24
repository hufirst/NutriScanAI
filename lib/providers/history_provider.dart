import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// Provider for scan history management
///
/// Manages loading, filtering, and displaying past scan results
class HistoryProvider extends ChangeNotifier {
  final StorageService _storageService;

  // State
  List<ScanResult> _scanHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _filterStatus = 'all'; // 'all', 'passed', 'warning', 'failed'
  String? _filterCategory;

  HistoryProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  // Getters
  List<ScanResult> get scanHistory => _scanHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get filterStatus => _filterStatus;
  String? get filterCategory => _filterCategory;

  /// Load recent scan history
  ///
  /// [limit] Maximum number of scans to load (default: 100)
  Future<void> loadHistory({int limit = AppConstants.chatHistoryLimit}) async {
    try {
      _setLoading(true);
      _clearError();

      final scanMaps = await _storageService.getRecentScanResults(limit: limit);
      _scanHistory = scanMaps.map((map) => ScanResult.fromMap(map)).toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load history: $e');
      debugPrint('History load error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load history filtered by validation status
  Future<void> loadByStatus(String status) async {
    try {
      _setLoading(true);
      _clearError();
      _filterStatus = status;
      _filterCategory = null; // Clear category filter

      if (status == 'all') {
        await loadHistory();
        return;
      }

      final scanMaps = await _storageService.getScanResultsByStatus(status);
      _scanHistory = scanMaps.map((map) => ScanResult.fromMap(map)).toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to filter by status: $e');
      debugPrint('Filter error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load history filtered by food category
  Future<void> loadByCategory(String category) async {
    try {
      _setLoading(true);
      _clearError();
      _filterCategory = category;
      _filterStatus = 'all'; // Clear status filter

      final scanMaps = await _storageService.getScanResultsByCategory(category);
      _scanHistory = scanMaps.map((map) => ScanResult.fromMap(map)).toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to filter by category: $e');
      debugPrint('Filter error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a scan result from history
  Future<bool> deleteScan(String scanId) async {
    try {
      await _storageService.deleteScanResult(scanId);

      // Remove from local list
      _scanHistory.removeWhere((scan) => scan.scanId == scanId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to delete scan: $e');
      debugPrint('Delete error: $e');
      return false;
    }
  }

  /// Clear all filters and reload
  Future<void> clearFilters() async {
    _filterStatus = 'all';
    _filterCategory = null;
    await loadHistory();
  }

  /// Refresh history (reload current filter)
  Future<void> refresh() async {
    if (_filterCategory != null) {
      await loadByCategory(_filterCategory!);
    } else if (_filterStatus != 'all') {
      await loadByStatus(_filterStatus);
    } else {
      await loadHistory();
    }
  }

  /// Get statistics for history
  Future<Map<String, int>> getStatistics() async {
    try {
      final statusCounts = await _storageService.getScanCountByStatus();
      final total = await _storageService.getTotalScanCount();

      return {
        'total': total,
        'passed': statusCounts['passed'] ?? 0,
        'warning': statusCounts['warning'] ?? 0,
        'failed': statusCounts['failed'] ?? 0,
      };
    } catch (e) {
      debugPrint('Statistics error: $e');
      return {'total': 0, 'passed': 0, 'warning': 0, 'failed': 0};
    }
  }

  // State management helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
