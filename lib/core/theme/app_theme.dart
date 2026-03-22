import 'package:flutter/material.dart';

/// 白守的主题配置
/// Sakura & Akatsuki 的配色风格
class AppTheme {
  AppTheme._();

  // 设计令牌 - 颜色
  static const Color primary = Color(0xFF5BA8F5);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color backgroundDark = Color(0xFF101922);
  static const Color surfaceDark = Color(0xFF192633); // 深色卡片背景
  static const Color surfaceHighlight = Color(0xFF233648);
  static const Color textSecondary = Color(0xFF92ADC9);

  // 字体族
  static const String fontFamily = 'Manrope';
  static const List<String> fontFamilyFallback = [
    'Microsoft YaHei',
    'Noto Sans SC',
    'PingFang SC',
    'sans-serif',
  ];

  static const Color textSecondaryLight = Color(0xFF475569); // slate-600
  static const Color textSecondaryDark = Color(0xFF94A3B8); // slate-400

  /// 亮色主题
  static ThemeData lightTheme(Color seedColor) {
    // seedColor 做选中态背景，加深后做 primary（保证对比度）
    const accentGreen = Color(0xFF4CAF50);
    // 加深 40%：用于按钮文字、图标、Switch 等需要对比度的地方
    final primaryDark = HSLColor.fromColor(seedColor)
        .withLightness((HSLColor.fromColor(seedColor).lightness - 0.25).clamp(0.2, 0.5))
        .withSaturation((HSLColor.fromColor(seedColor).saturation + 0.15).clamp(0.0, 1.0))
        .toColor();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
        primary: primaryDark,
        onPrimary: Colors.white,
        primaryContainer: seedColor, // 马卡龙原色做选中背景
        onPrimaryContainer: const Color(0xFF1565C0),
        secondary: const Color(0xFF78909C), // 蓝灰次要色
        tertiary: accentGreen,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFE8F5E9), // 浅绿容器
        surface: Colors.white,  // 卡片纯白
        onSurface: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFFE8E8E8),
        surfaceContainerHigh: const Color(0xFFEEEEEE),
        surfaceContainer: const Color(0xFFF2F2F2),
        surfaceContainerLow: const Color(0xFFF6F7F8),  // 接近背景
        surfaceContainerLowest: Colors.white,
        surfaceTint: Colors.transparent,
        outline: const Color(0xFF9E9E9E),
        outlineVariant: const Color(0xFFD0D0D0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      // ... timePickerTheme unchanged ...
    );
  }

  /// 暗色主题
  static ThemeData darkTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        surfaceTint: Colors.transparent,
        surface: surfaceDark,
        background: backgroundDark,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      // ... timePickerTheme unchanged ...
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
}
