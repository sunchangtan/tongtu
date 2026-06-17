import 'package:flutter/material.dart';

/// 通途 App 主题配色：由品牌色推导，明暗两套（Material 3）。
///
/// 配色源：`docs/design/logo-spec.md`
/// - Primary（主色）= 品牌靛蓝 `#3F51B5`
/// - Secondary（次色）= 品牌蓝青 `#1E9BD4`
///
/// 与 Figma「Tongtu Brand」文件的 `App Theme` 变量集合（Light / Dark 两 mode）一一对应。
/// 以 `ColorScheme.fromSeed` 生成完整且版本兼容的 M3 调色，再用品牌精确色覆盖关键 token。
class AppTheme {
  AppTheme._();

  /// 浅色配色方案。
  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF3F51B5),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFE0E2FB),
        onPrimaryContainer: const Color(0xFF161A4E),
        secondary: const Color(0xFF1E9BD4),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFD7EEF9),
        onSecondaryContainer: const Color(0xFF0A5B7A),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1A1C2A),
        outline: const Color(0xFFC4C6D0),
        error: const Color(0xFFBA1A1A),
        onError: const Color(0xFFFFFFFF),
      );

  /// 深色配色方案。
  static final ColorScheme darkScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFBBC3FF),
        onPrimary: const Color(0xFF1A2270),
        primaryContainer: const Color(0xFF2B3590),
        onPrimaryContainer: const Color(0xFFDFE1FB),
        secondary: const Color(0xFF8DD2F2),
        onSecondary: const Color(0xFF06384B),
        secondaryContainer: const Color(0xFF143C4E),
        onSecondaryContainer: const Color(0xFFBCE7FB),
        surface: const Color(0xFF15161B),
        onSurface: const Color(0xFFE4E2E9),
        outline: const Color(0xFF8E9099),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      );

  /// 浅色主题。
  static final ThemeData light = ThemeData(
    colorScheme: lightScheme,
    useMaterial3: true,
  );

  /// 深色主题。
  static final ThemeData dark = ThemeData(
    colorScheme: darkScheme,
    useMaterial3: true,
  );
}
