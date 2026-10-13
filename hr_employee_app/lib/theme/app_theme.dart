import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  static const Color primaryColor = AppColors.navy;
  static const Color white = AppColors.white;
  static const Color background = AppColors.background;
  static const Color cardSurface = AppColors.surface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color border = AppColors.border;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    const colorScheme = ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: AppColors.white,
      secondary: AppColors.emerald,
      onSecondary: AppColors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.white,
      outline: AppColors.border,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: AppColors.navy,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme
          .apply(fontFamily: 'Roboto')
          .copyWith(
            displayLarge: AppTextStyles.display.copyWith(fontSize: 57),
            displayMedium: AppTextStyles.display.copyWith(fontSize: 45),
            displaySmall: AppTextStyles.display.copyWith(fontSize: 36),
            headlineLarge: AppTextStyles.screenTitle.copyWith(fontSize: 32),
            headlineMedium: AppTextStyles.screenTitle.copyWith(fontSize: 28),
            headlineSmall: AppTextStyles.screenTitle.copyWith(fontSize: 24),
            titleLarge: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
            titleMedium: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            titleSmall: AppTextStyles.cardTitle,
            bodyLarge: AppTextStyles.body.copyWith(fontSize: 16),
            bodyMedium: AppTextStyles.body,
            bodySmall: AppTextStyles.metadata,
            labelLarge: AppTextStyles.button,
            labelMedium: AppTextStyles.fieldLabel,
            labelSmall: AppTextStyles.status,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.screenTitle,
        iconTheme: IconThemeData(color: AppColors.navy, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.deepNavy.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: AppSpacing.sm,
        iconColor: AppColors.info,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.cardTitle,
        subtitleTextStyle: AppTextStyles.secondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: AppTextStyles.button,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.green.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: AppTextStyles.button,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: const Size(44, 44),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: AppTextStyles.fieldLabel,
        hintStyle: AppTextStyles.secondary,
        errorStyle: AppTextStyles.metadata.copyWith(color: AppColors.error),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: AppSpacing.xl,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.infoSurface,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        labelStyle: AppTextStyles.metadata.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.emerald,
        linearTrackColor: AppColors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.extraLarge),
        ),
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
        contentTextStyle: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.white,
        elevation: 2,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepNavy,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      splashColor: AppColors.emerald.withValues(alpha: 0.08),
      highlightColor: AppColors.navy.withValues(alpha: 0.04),
      hoverColor: AppColors.navy.withValues(alpha: 0.04),
    );
  }
}
