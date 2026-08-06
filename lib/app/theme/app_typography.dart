import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const double metric = 48;
  static const double titleLg = 24;
  static const double titleMd = 20;
  static const double bodyLg = 17;
  static const double bodyMd = 15;
  static const double caption = 13;

  static const FontFeature _tabular = FontFeature.tabularFigures();

  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final muted = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      displayMedium: TextStyle(
        fontSize: metric,
        height: 56 / 48,
        fontWeight: FontWeight.w700,
        color: onSurface,
        fontFeatures: [_tabular],
      ),
      headlineSmall: TextStyle(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: titleLg,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: titleMd,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLg,
        height: 26 / 17,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMd,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: bodyMd,
        height: 22 / 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: caption,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }
}
