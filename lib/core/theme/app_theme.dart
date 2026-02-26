import 'package:flutter/material.dart';

/// 白守的主题配置
/// Sakura & Akatsuki 的配色风格
class AppTheme {
  AppTheme._();

  // 设计令牌 - 颜色
  static const Color primary = Color(0xFF137FEC);
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
        surfaceTint: Colors.transparent,
        surface: Colors.white,
        background: backgroundLight,
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
