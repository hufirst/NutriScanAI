/// Application-wide constants for TanDanGenie
///
/// This file contains all configuration values, thresholds, and static settings
/// used throughout the application. Centralized constants ensure consistency
/// and make it easier to adjust configuration values.
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // ============================================================================
  // API Configuration
  // ============================================================================

  /// Gemini AI model identifier
  /// Using Gemini 2.5-flash-lite for fastest processing speed
  /// Test results: 100% accuracy (1/1 successful), 7.7s average processing time (fastest)
  static const String geminiModel = 'gemini-2.5-flash-lite';

  /// Base URL for Gemini API
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  // ============================================================================
  // Validation Thresholds
  // ============================================================================

  /// Minimum confidence score for accepting OCR/classification results
  /// Results below this threshold are stored as raw data only
  static const double confidenceThreshold = 0.85;

  /// Acceptable tolerance for ratio sum validation
  /// Ratios must sum to 100 ± this value (in percentage points)
  static const int ratioSumTolerance = 5;

  /// Minimum ratio value (percentage)
  static const int minRatioValue = 0;

  /// Maximum ratio value (percentage)
  static const int maxRatioValue = 100;

  /// Minimum calorie value (kcal per 100g)
  static const int minCalories = 0;

  /// Maximum reasonable calorie value (kcal per 100g)
  static const int maxCalories = 900;

  // ============================================================================
  // UI Configuration
  // ============================================================================

  /// Maximum number of chat messages to display in history
  static const int chatHistoryLimit = 100;

  /// Food emojis for carbohydrate, protein, fat display
  static const String carbEmoji = '🥖';
  static const String proteinEmoji = '🍗';
  static const String fatEmoji = '🥑';

  /// Default padding for chat bubbles (in logical pixels)
  static const double chatBubblePadding = 12.0;

  /// Default border radius for rounded corners
  static const double defaultBorderRadius = 16.0;

  // ============================================================================
  // Timeout Configuration
  // ============================================================================

  /// Maximum time to wait for Gemini API response
  /// Increased to 30s for image analysis
  static const Duration geminiTimeout = Duration(seconds: 30);

  /// Maximum time to wait for Fivetran webhook response
  static const Duration fivetranTimeout = Duration(seconds: 5);

  /// Maximum time to wait for camera initialization
  static const Duration cameraTimeout = Duration(seconds: 15);

  // ============================================================================
  // Retry Policy
  // ============================================================================

  /// Maximum number of retry attempts for failed API calls
  static const int maxRetries = 3;

  /// Initial delay before first retry (exponential backoff)
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  /// Maximum delay between retries
  static const Duration maxRetryDelay = Duration(seconds: 5);

  // ============================================================================
  // Database Configuration
  // ============================================================================

  /// SQLite database filename
  static const String databaseName = 'tandangenie.db';

  /// Database version (increment when schema changes)
  static const int databaseVersion = 4;

  /// Maximum number of records to keep in history
  static const int maxHistoryRecords = 1000;

  // ============================================================================
  // Validation Status Enum Values
  // ============================================================================

  static const String validationStatusPassed = 'passed';
  static const String validationStatusWarning = 'warning';
  static const String validationStatusFailed = 'failed';
  static const String validationStatusPending = 'pending';

  // ============================================================================
  // Image Configuration
  // ============================================================================

  /// Maximum image size for upload (in bytes, 5MB)
  static const int maxImageSize = 5 * 1024 * 1024;

  /// Image quality for compression (0-100)
  static const int imageQuality = 85;

  /// Default camera resolution width
  static const int cameraResolutionWidth = 1920;

  /// Default camera resolution height
  static const int cameraResolutionHeight = 1080;
}
