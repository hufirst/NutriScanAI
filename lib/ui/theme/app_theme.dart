import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// KakaoTalk-inspired theme for TanDanGenie
///
/// This theme provides a clean, chat-focused design language inspired by
/// KakaoTalk's familiar interface. The color scheme uses warm yellows and
/// clean whites to create a friendly, approachable feel.
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // ============================================================================
  // Color Palette (KakaoTalk-inspired)
  // ============================================================================

  /// Primary brand color (KakaoTalk yellow)
  static const Color primaryColor = Color(0xFFFFE812);

  /// Darker shade of primary color for contrast
  static const Color primaryDark = Color(0xFFD9C100);

  /// Background color for the main screen
  static const Color backgroundColor = Color(0xFFF5F5F5);

  /// Color for user's own chat bubbles (sent messages)
  static const Color userBubbleColor = Color(0xFFFFE812);

  /// Color for system/AI chat bubbles (received messages)
  static const Color aiBubbleColor = Color(0xFFFFFFFF);

  /// Text color for user bubbles
  static const Color userBubbleTextColor = Color(0xFF3C1E1E);

  /// Text color for AI bubbles
  static const Color aiBubbleTextColor = Color(0xFF000000);

  /// Border color for chat bubbles and cards
  static const Color borderColor = Color(0xFFE0E0E0);

  /// Error color for validation failures
  static const Color errorColor = Color(0xFFD32F2F);

  /// Success color for passed validations
  static const Color successColor = Color(0xFF388E3C);

  /// Warning color for low-confidence results
  static const Color warningColor = Color(0xFFF57C00);

  /// Text color for primary content
  static const Color textPrimary = Color(0xFF000000);

  /// Text color for secondary content
  static const Color textSecondary = Color(0xFF757575);

  /// Text color for disabled/hint content
  static const Color textHint = Color(0xFFBDBDBD);

  // ============================================================================
  // Light Theme
  // ============================================================================

  static ThemeData get lightTheme {
    return ThemeData(
      // Base configuration
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: userBubbleTextColor,
        secondary: primaryDark,
        onSecondary: userBubbleTextColor,
        surface: backgroundColor,
        onSurface: textPrimary,
        error: errorColor,
        onError: Colors.white,
      ),

      // Scaffold background
      scaffoldBackgroundColor: backgroundColor,

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: userBubbleTextColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: userBubbleTextColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansKR',
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: userBubbleTextColor,
        elevation: 4,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryDark,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text theme
      textTheme: const TextTheme(
        // Display styles
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),

        // Headline styles
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),

        // Title styles
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          fontFamily: 'NotoSansKR',
        ),

        // Body styles
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondary,
          fontFamily: 'NotoSansKR',
        ),

        // Label styles
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'NotoSansKR',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          fontFamily: 'NotoSansKR',
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textHint,
          fontFamily: 'NotoSansKR',
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: userBubbleTextColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSansKR',
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSansKR',
          ),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
    );
  }

  // ============================================================================
  // Custom Chat Bubble Decorations
  // ============================================================================

  /// Decoration for user's own messages (sent)
  static BoxDecoration get userBubbleDecoration {
    return BoxDecoration(
      color: userBubbleColor,
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Decoration for AI/system messages (received)
  static BoxDecoration get aiBubbleDecoration {
    return BoxDecoration(
      color: aiBubbleColor,
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Text style for ratio numbers in chat
  static const TextStyle ratioNumberStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    fontFamily: 'NotoSansKR',
  );

  /// Text style for food emojis in chat
  static const TextStyle emojiStyle = TextStyle(
    fontSize: 24,
  );
}
