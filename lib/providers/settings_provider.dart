import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

/// Provider for user settings management
///
/// Manages app settings like target ratios, notifications, and sync preferences
class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  // State
  Map<String, String> _settings = {};
  bool _isLoading = false;
  String? _errorMessage;

  SettingsProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    loadSettings();
  }

  // Getters
  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Convenience getters for common settings
  int get targetCarbRatio =>
      int.tryParse(_settings['target_carb_ratio'] ?? '40') ?? 40;
  int get targetProteinRatio =>
      int.tryParse(_settings['target_protein_ratio'] ?? '30') ?? 30;
  int get targetFatRatio =>
      int.tryParse(_settings['target_fat_ratio'] ?? '30') ?? 30;
  bool get notificationsEnabled =>
      (_settings['notifications_enabled'] ?? '1') == '1';
  bool get autoFivetranSync =>
      (_settings['auto_fivetran_sync'] ?? '1') == '1';

  /// Load all settings from database
  Future<void> loadSettings() async {
    try {
      _setLoading(true);
      _clearError();

      _settings = await _storageService.getAllSettings();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load settings: $e');
      debugPrint('Settings load error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update a single setting
  Future<bool> updateSetting(String key, String value) async {
    try {
      await _storageService.setSetting(key, value);
      _settings[key] = value;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update setting: $e');
      debugPrint('Setting update error: $e');
      return false;
    }
  }

  /// Update target ratios (must sum to 100)
  Future<bool> updateTargetRatios({
    required int carbRatio,
    required int proteinRatio,
    required int fatRatio,
  }) async {
    if (carbRatio + proteinRatio + fatRatio != 100) {
      _setError('Ratios must sum to 100');
      return false;
    }

    try {
      await _storageService.setSetting('target_carb_ratio', carbRatio.toString());
      await _storageService.setSetting('target_protein_ratio', proteinRatio.toString());
      await _storageService.setSetting('target_fat_ratio', fatRatio.toString());

      _settings['target_carb_ratio'] = carbRatio.toString();
      _settings['target_protein_ratio'] = proteinRatio.toString();
      _settings['target_fat_ratio'] = fatRatio.toString();

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update target ratios: $e');
      debugPrint('Target ratios update error: $e');
      return false;
    }
  }

  /// Toggle notifications
  Future<bool> toggleNotifications() async {
    final newValue = notificationsEnabled ? '0' : '1';
    return await updateSetting('notifications_enabled', newValue);
  }

  /// Toggle auto Fivetran sync
  Future<bool> toggleAutoSync() async {
    final newValue = autoFivetranSync ? '0' : '1';
    return await updateSetting('auto_fivetran_sync', newValue);
  }

  /// Reset all settings to defaults
  Future<bool> resetToDefaults() async {
    try {
      await _storageService.setSetting('target_carb_ratio', '40');
      await _storageService.setSetting('target_protein_ratio', '30');
      await _storageService.setSetting('target_fat_ratio', '30');
      await _storageService.setSetting('notifications_enabled', '1');
      await _storageService.setSetting('auto_fivetran_sync', '1');

      await loadSettings();
      return true;
    } catch (e) {
      _setError('Failed to reset settings: $e');
      debugPrint('Settings reset error: $e');
      return false;
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
