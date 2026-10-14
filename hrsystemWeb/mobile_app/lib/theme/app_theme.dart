import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF101B36); // Navy Blue
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FB);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF101B36);
  static const Color textSecondary = Color(0xFF64748B);

  // Border Colors
  static const Color border = Color(0xFFE2E8F0);

  // Status Colors
  static const Color success = Color(0xFF10B981); // Professional green
  static const Color warning = Color(0xFFF59E0B); // Professional amber
  static const Color error = Color(0xFFEF4444); // Professional red

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: white,
        surface: cardSurface,
        onSurface: textPrimary,
        error: error,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 36,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 32,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 28,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 26,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 23,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.35,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Montserrat',
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 14,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          height: 1.3,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
        hintStyle: const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          color: textSecondary,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: primaryColor,
        contentTextStyle: TextStyle(color: white, fontFamily: 'Roboto'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData forViewportWidth(double width) {
    final theme = lightTheme;
    if (width >= 380) return theme;

    final scale = width < 340 ? 0.9 : 0.95;
    TextStyle? compact(TextStyle? style) {
      final size = style?.fontSize;
      return size == null ? style : style!.copyWith(fontSize: size * scale);
    }

    final text = theme.textTheme;
    return theme.copyWith(
      textTheme: text.copyWith(
        displayLarge: compact(text.displayLarge),
        displayMedium: compact(text.displayMedium),
        displaySmall: compact(text.displaySmall),
        headlineLarge: compact(text.headlineLarge),
        headlineMedium: compact(text.headlineMedium),
        headlineSmall: compact(text.headlineSmall),
        titleLarge: compact(text.titleLarge),
        titleMedium: compact(text.titleMedium),
        titleSmall: compact(text.titleSmall),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: compact(theme.appBarTheme.titleTextStyle),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle: compact(theme.dialogTheme.titleTextStyle),
      ),
    );
  }
}
