import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_colors_extension.dart';
import 'app_typography.dart';
import 'app_radius.dart';
import 'app_animations.dart';

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
        error: AppColors.error,
        onSecondary: Colors.white,
        surfaceContainerHighest: AppColors.backgroundLight,
      ),

      // 自适应颜色扩展
      extensions: const <ThemeExtension>[
        AppColorsExtension.light,
      ],

      // 页面转场动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
          fontFamily: 'Inter',
          color: AppColors.textPrimaryLight,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
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
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      // NavigationBar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.cardBackgroundLight,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.caption.copyWith(
            color: AppColors.textSecondaryLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondaryLight, size: 24);
        }),
      ),

      // TabBar 主题
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: AppTypography.subheadlineBold,
        unselectedLabelStyle: AppTypography.subheadline,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.08)),
      ),

      // Chip 主题
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        disabledColor: AppColors.backgroundLight,
        labelStyle: AppTypography.tag.copyWith(color: AppColors.textPrimaryLight),
        secondaryLabelStyle: AppTypography.tag.copyWith(color: AppColors.primary),
        side: BorderSide(color: AppColors.separatorLight.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allPill),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackgroundLight,
        surfaceTintColor: AppColors.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: AppColors.separatorLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // 按钮主题（关闭水波纹/焦点高亮，避免 Web 及移动端点击时闪烁）
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
          animationDuration: AppAnimations.fast,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
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
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTypography.button,
          animationDuration: AppAnimations.fast,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      // FloatingActionButton 主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLarge,
        ),
      ),

      // Switch 主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textTertiaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.separatorLight;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Slider 主题
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // Badge 主题
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.badgeRed,
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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

      // Tooltip 主题
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimaryLight.withValues(alpha: 0.9),
          borderRadius: AppRadius.allSmall,
        ),
        textStyle: AppTypography.caption.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // PopupMenu 主题
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        color: AppColors.cardBackgroundLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
        textStyle: AppTypography.body.copyWith(color: AppColors.textPrimaryLight),
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
        dragHandleColor: AppColors.separatorLight,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
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

      // 图标按钮（关闭水波纹，避免 Web 闪烁）
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      // 进度指示器主题
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primary.withValues(alpha: 0.12),
        circularTrackColor: AppColors.primary.withValues(alpha: 0.12),
      ),

      // 搜索栏主题
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(AppColors.backgroundLight),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: AppRadius.allPill,
            side: const BorderSide(color: AppColors.dividerLight),
          ),
        ),
        hintStyle: WidgetStateProperty.all(
          AppTypography.body.copyWith(color: AppColors.textPlaceholderLight),
        ),
        textStyle: WidgetStateProperty.all(
          AppTypography.body.copyWith(color: AppColors.textPrimaryLight),
        ),
      ),

      // SegmentedButton 主题（关闭水波纹，避免 Web 闪烁）
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.textPrimaryLight;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
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
        onError: Colors.white,
        surfaceContainerHighest: AppColors.secondaryBackgroundDark,
      ),

      // 自适应颜色扩展
      extensions: const <ThemeExtension>[
        AppColorsExtension.dark,
      ],

      // 页面转场动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
          fontFamily: 'Inter',
          color: AppColors.textPrimaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
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
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      // NavigationBar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.cardBackgroundDark,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.caption.copyWith(
            color: AppColors.textSecondaryDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondaryDark, size: 24);
        }),
      ),

      // TabBar 主题
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: AppTypography.subheadlineBold,
        unselectedLabelStyle: AppTypography.subheadline,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.12)),
      ),

      // Chip 主题
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondaryBackgroundDark,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        disabledColor: AppColors.secondaryBackgroundDark,
        labelStyle: AppTypography.tag.copyWith(color: AppColors.textPrimaryDark),
        secondaryLabelStyle: AppTypography.tag.copyWith(color: AppColors.primary),
        side: BorderSide(color: AppColors.separatorDark.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allPill),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackgroundDark,
        surfaceTintColor: AppColors.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: AppColors.separatorDark.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // 按钮主题（关闭水波纹/焦点高亮，避免 Web 及移动端点击时闪烁）
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
          animationDuration: AppAnimations.fast,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
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
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTypography.button,
          animationDuration: AppAnimations.fast,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.allMedium,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      // FloatingActionButton 主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLarge,
        ),
      ),

      // Switch 主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textTertiaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.separatorDark;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Slider 主题
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.2),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // Badge 主题
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.badgeRed,
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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

      // Tooltip 主题
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.elevatedBackgroundDark,
          borderRadius: AppRadius.allSmall,
          border: Border.all(color: AppColors.separatorDark.withValues(alpha: 0.3)),
        ),
        textStyle: AppTypography.caption.copyWith(color: AppColors.textPrimaryDark),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // PopupMenu 主题
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        color: AppColors.elevatedBackgroundDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
        textStyle: AppTypography.body.copyWith(color: AppColors.textPrimaryDark),
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
        dragHandleColor: AppColors.separatorDark,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
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

      // 图标按钮（关闭水波纹，避免 Web 闪烁）
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),

      // 进度指示器主题
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primary.withValues(alpha: 0.15),
        circularTrackColor: AppColors.primary.withValues(alpha: 0.15),
      ),

      // 搜索栏主题
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(AppColors.secondaryBackgroundDark),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: AppRadius.allPill,
            side: const BorderSide(color: AppColors.dividerDark),
          ),
        ),
        hintStyle: WidgetStateProperty.all(
          AppTypography.body.copyWith(color: AppColors.textPlaceholderDark),
        ),
        textStyle: WidgetStateProperty.all(
          AppTypography.body.copyWith(color: AppColors.textPrimaryDark),
        ),
      ),

      // SegmentedButton 主题（关闭水波纹，避免 Web 闪烁）
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return AppColors.textPrimaryDark;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: AppRadius.allMedium),
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
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
