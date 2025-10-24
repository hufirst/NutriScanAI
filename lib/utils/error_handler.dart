import 'dart:async';
import 'dart:io';
import '../utils/constants.dart';

/// Error handling utilities with retry logic and exponential backoff
///
/// Implements retry policies for network calls and API requests
class ErrorHandler {
  ErrorHandler._(); // Prevent instantiation

  /// Execute function with retry logic and exponential backoff
  ///
  /// [fn] Function to execute
  /// [maxRetries] Maximum number of retry attempts (default: 3)
  /// [initialDelay] Initial delay before first retry (default: 500ms)
  /// [onRetry] Optional callback called before each retry
  ///
  /// Returns result of function execution
  /// Throws original exception if all retries fail
  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxRetries = AppConstants.maxRetries,
    Duration initialDelay = AppConstants.initialRetryDelay,
    void Function(int attempt, Object error)? onRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      try {
        return await fn();
      } catch (error) {
        attempt++;

        // If max retries reached, rethrow the error
        if (attempt >= maxRetries) {
          rethrow;
        }

        // Check if error is retryable
        if (!_isRetryable(error)) {
          rethrow;
        }

        // Call onRetry callback if provided
        onRetry?.call(attempt, error);

        // Wait before retry with exponential backoff
        await Future.delayed(currentDelay);

        // Double the delay for next retry (exponential backoff)
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * 2)
              .clamp(0, AppConstants.maxRetryDelay.inMilliseconds),
        );
      }
    }
  }

  /// Check if error is retryable
  ///
  /// Returns true for network errors, timeouts, and 5xx server errors
  /// Returns false for client errors (4xx), validation errors, etc.
  static bool _isRetryable(Object error) {
    // Network errors and timeouts are retryable
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;

    // Check error message for retryable patterns
    final errorMessage = error.toString().toLowerCase();

    // Server errors (5xx) are retryable
    if (errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503') ||
        errorMessage.contains('504') ||
        errorMessage.contains('server error') ||
        errorMessage.contains('service unavailable')) {
      return true;
    }

    // Rate limiting (429) is retryable
    if (errorMessage.contains('429') ||
        errorMessage.contains('too many requests') ||
        errorMessage.contains('rate limit')) {
      return true;
    }

    // Temporary network issues are retryable
    if (errorMessage.contains('connection') ||
        errorMessage.contains('network') ||
        errorMessage.contains('timeout')) {
      return true;
    }

    // Client errors (4xx except 429), validation errors are not retryable
    if (errorMessage.contains('400') ||
        errorMessage.contains('401') ||
        errorMessage.contains('403') ||
        errorMessage.contains('404') ||
        errorMessage.contains('invalid') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('forbidden')) {
      return false;
    }

    // Default: not retryable
    return false;
  }

  /// Calculate next retry timestamp using exponential backoff
  ///
  /// [retryCount] Current retry attempt number (0-indexed)
  /// [initialDelay] Base delay for first retry
  ///
  /// Returns DateTime for next retry attempt
  static DateTime calculateNextRetryAt(
    int retryCount, {
    Duration initialDelay = AppConstants.initialRetryDelay,
  }) {
    // Calculate delay with exponential backoff: initialDelay * 2^retryCount
    final delayMs = initialDelay.inMilliseconds * (1 << retryCount);

    // Clamp to maximum delay
    final clampedDelayMs =
        delayMs.clamp(0, AppConstants.maxRetryDelay.inMilliseconds);

    return DateTime.now().add(Duration(milliseconds: clampedDelayMs));
  }

  /// Format error message for user display
  ///
  /// Converts technical errors to user-friendly messages
  static String formatUserMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    // Gemini 분석 실패 (영양성분표 미포함 또는 이미지 품질 문제)
    if (errorStr.contains('missing required nutrition field') ||
        errorStr.contains('carbohydrates_g') ||
        errorStr.contains('calories') && errorStr.contains('null')) {
      return '사진 분석에 실패했습니다. 영양성분표가 선명하게 보이도록 다시 촬영해주세요.';
    }

    // 이미지 품질 문제
    if (errorStr.contains('image quality') || errorStr.contains('low quality')) {
      return '사진 품질이 낮습니다. 밝은 곳에서 영양성분표를 선명하게 촬영해주세요.';
    }

    if (errorStr.contains('timeout')) {
      return '요청 시간이 초과되었습니다. 인터넷 연결을 확인해주세요.';
    }

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return '네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인해주세요.';
    }

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'API 인증에 실패했습니다. 관리자에게 문의해주세요.';
    }

    if (errorStr.contains('429') || errorStr.contains('rate limit')) {
      return '요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (errorStr.contains('500') || errorStr.contains('server error')) {
      return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (errorStr.contains('invalid') || errorStr.contains('parse')) {
      return '데이터 처리 중 오류가 발생했습니다. 다시 촬영해주세요.';
    }

    // Default: 이미지 분석 실패로 간주
    return '사진 분석에 실패했습니다. 영양성분표가 포함된 사진으로 다시 시도해주세요.';
  }
}
