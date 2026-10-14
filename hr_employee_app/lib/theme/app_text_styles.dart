import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: AppColors.textPrimary,
  );

  static const screenTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const cardTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const secondary = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const fieldLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const button = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const metadata = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const status = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static const metric = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 27,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
