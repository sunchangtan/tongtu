import 'package:flutter/material.dart';

import 'tokens/tokens.g.dart';
import 'tokens/typography.g.dart';

/// 通途 App 主题配色：由生成的设计 token 推导，明暗两套（Material 3）。
///
/// 颜色源：`tokens/*.json`（Figma 变量）→ `lib/ui/tokens/tokens.g.dart`（生成）。
/// 改色请改 Figma 变量 → 重新导出 DTCG → `node tools/style-dictionary/build.mjs`，
/// 不在此硬编码。
///
/// 以 `ColorScheme.fromSeed` 生成完整 M3 调色打底，再用生成的明 / 暗语义色常量
/// 覆盖品牌关键角色（见 `openspec/changes/design-token-sync` design D3）。
/// token 中的 background / surface-variant 等在 Flutter M3 已并入 surface 体系，
/// 此处不单独映射；其值仍供 CSS / 其他端使用。
class AppTheme {
  AppTheme._();

  /// 浅色配色方案。
  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(
        seedColor: TongtuSysColorsLight.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: TongtuSysColorsLight.primary,
        onPrimary: TongtuSysColorsLight.onPrimary,
        primaryContainer: TongtuSysColorsLight.primaryContainer,
        onPrimaryContainer: TongtuSysColorsLight.onPrimaryContainer,
        secondary: TongtuSysColorsLight.secondary,
        onSecondary: TongtuSysColorsLight.onSecondary,
        secondaryContainer: TongtuSysColorsLight.secondaryContainer,
        onSecondaryContainer: TongtuSysColorsLight.onSecondaryContainer,
        surface: TongtuSysColorsLight.surface,
        onSurface: TongtuSysColorsLight.onSurface,
        outline: TongtuSysColorsLight.outline,
        error: TongtuSysColorsLight.error,
        onError: TongtuSysColorsLight.onError,
      );

  /// 深色配色方案。
  static final ColorScheme darkScheme =
      ColorScheme.fromSeed(
        seedColor: TongtuSysColorsLight.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: TongtuSysColorsDark.primary,
        onPrimary: TongtuSysColorsDark.onPrimary,
        primaryContainer: TongtuSysColorsDark.primaryContainer,
        onPrimaryContainer: TongtuSysColorsDark.onPrimaryContainer,
        secondary: TongtuSysColorsDark.secondary,
        onSecondary: TongtuSysColorsDark.onSecondary,
        secondaryContainer: TongtuSysColorsDark.secondaryContainer,
        onSecondaryContainer: TongtuSysColorsDark.onSecondaryContainer,
        surface: TongtuSysColorsDark.surface,
        onSurface: TongtuSysColorsDark.onSurface,
        outline: TongtuSysColorsDark.outline,
        error: TongtuSysColorsDark.error,
        onError: TongtuSysColorsDark.onError,
      );

  /// 浅色主题。
  static final ThemeData light = ThemeData(
    colorScheme: lightScheme,
    useMaterial3: true,
    textTheme: tongtuTextTheme,
  );

  /// 深色主题。
  static final ThemeData dark = ThemeData(
    colorScheme: darkScheme,
    useMaterial3: true,
    textTheme: tongtuTextTheme,
  );
}
