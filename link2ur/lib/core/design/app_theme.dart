import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

/// 应用主题
/// 参考iOS DesignSystem.swift
class AppTheme {
  AppTheme._();

  // ==================== 浅色主题 ====================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // 颜色方案
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardBackgroundLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
      ),

      // AppBar主题
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimaryLight,
          size: 24,
        ),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.cardBackgroundLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      // 卡片主题 - 与iOS对齐添加微妙边框(separator.opacity(0.3), 0.5pt)
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: AppColors.separatorLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // 按钮主题 - 高度对齐iOS 50pt
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: AppTypography.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBackgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textPlaceholderLight,
        ),
        labelStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondaryLight,
        ),
        errorStyle: AppTypography.caption.copyWith(
          color: AppColors.error,
        ),
      ),

      // 分隔线主题
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 0.5,
        space: 0,
      ),

      // 列表主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        tileColor: AppColors.cardBackgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
        ),
      ),

      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackgroundLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLarge,
        ),
        titleTextStyle: AppTypography.title3.copyWith(
          color: AppColors.textPrimaryLight,
        ),
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondaryLight,
        ),
      ),

      // 底部Sheet主题
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackgroundLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.modal,
        ),
        modalElevation: 0,
        modalBackgroundColor: AppColors.cardBackgroundLight,
      ),

      // Snackbar主题
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: AppTypography.body.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
        ),
      ),

      // 文字主题
      textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),

      // 图标主题
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: 24,
      ),

      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  // ==================== 深色主题 ====================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // 颜色方案
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardBackgroundDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onError: Colors.white,
      ),

      // AppBar主题
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimaryDark,
          size: 24,
        ),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.cardBackgroundDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      // 卡片主题 - 与iOS对齐添加微妙边框(separator.opacity(0.3), 0.5pt)
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: AppColors.separatorDark.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // 按钮主题 - 高度对齐iOS 50pt
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: AppTypography.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBackgroundDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textPlaceholderDark,
        ),
        labelStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondaryDark,
        ),
        errorStyle: AppTypography.caption.copyWith(
          color: AppColors.error,
        ),
      ),

      // 分隔线主题
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 0.5,
        space: 0,
      ),

      // 列表主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        tileColor: AppColors.cardBackgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
        ),
      ),

      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackgroundDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLarge,
        ),
        titleTextStyle: AppTypography.title3.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondaryDark,
        ),
      ),

      // 底部Sheet主题
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackgroundDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.modal,
        ),
        modalElevation: 0,
        modalBackgroundColor: AppColors.cardBackgroundDark,
      ),

      // Snackbar主题
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedBackgroundDark,
        contentTextStyle: AppTypography.body.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
        ),
      ),

      // 文字主题
      textTheme: _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),

      // 图标主题
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: 24,
      ),

      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  // ==================== 文字主题 ====================
  static TextTheme _textTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: AppTypography.largeTitle.copyWith(color: primaryColor),
      displayMedium: AppTypography.title.copyWith(color: primaryColor),
      displaySmall: AppTypography.title2.copyWith(color: primaryColor),
      headlineLarge: AppTypography.title.copyWith(color: primaryColor),
      headlineMedium: AppTypography.title2.copyWith(color: primaryColor),
      headlineSmall: AppTypography.title3.copyWith(color: primaryColor),
      titleLarge: AppTypography.title3.copyWith(color: primaryColor),
      titleMedium: AppTypography.bodyBold.copyWith(color: primaryColor),
      titleSmall: AppTypography.subheadlineBold.copyWith(color: primaryColor),
      bodyLarge: AppTypography.body.copyWith(color: primaryColor),
      bodyMedium: AppTypography.callout.copyWith(color: primaryColor),
      bodySmall: AppTypography.subheadline.copyWith(color: secondaryColor),
      labelLarge: AppTypography.button.copyWith(color: primaryColor),
      labelMedium: AppTypography.footnote.copyWith(color: secondaryColor),
      labelSmall: AppTypography.caption.copyWith(color: secondaryColor),
    );
  }
}
