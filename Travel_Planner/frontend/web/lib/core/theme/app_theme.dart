import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Enterprise Theme configuration for Travel Planner Web Admin.
/// Standardized according to Professional Enterprise SaaS Admin / Minimalism & Swiss Style.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titlePage,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1.0,
        space: 1.0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 2,
        shadowColor: const Color(0x1A000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: AppTypography.titleSection,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(
            color: AppColors.primaryAccessible,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.mutedSoft,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.primaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primaryDark;
            }
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, AppHeights.buttonStandard)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return Colors.transparent;
            if (states.contains(WidgetState.pressed)) return AppColors.surfaceHover;
            if (states.contains(WidgetState.hovered)) return AppColors.surfaceSubtle;
            return AppColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
            if (states.contains(WidgetState.hovered)) return AppColors.textPrimary;
            return AppColors.textSecondary;
          }),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, AppHeights.buttonStandard)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(color: AppColors.borderStrong, width: 1);
            }
            return const BorderSide(color: AppColors.border, width: 1);
          }),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
            if (states.contains(WidgetState.hovered)) return AppColors.primaryDark;
            return AppColors.primaryAccessible;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.hovered)) return AppColors.primaryTint;
            return Colors.transparent;
          }),
          minimumSize: const WidgetStatePropertyAll<Size>(Size(48, AppHeights.buttonSmall)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: AppHeights.tableHeader,
        dataRowMinHeight: AppHeights.tableRow,
        dataRowMaxHeight: AppHeights.tableRowComfortable,
        columnSpacing: 24,
        horizontalMargin: 16,
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceSubtle),
        headingTextStyle: AppTypography.captionTable,
        dataTextStyle: AppTypography.bodyData,
        dividerThickness: 1,
      ),
    );
  }
}
