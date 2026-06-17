import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens/tokens.g.dart';
import 'tokens/typography.g.dart';

/// 通途自定义 token（ThemeExtension）：放 M3 `ColorScheme` / `textTheme` 之外的
/// 通途可定制项（扩展层，见 `docs/design/component-contract.md` §6）。
/// v1 仅 `buttonMinHeight` 作扩展点示范，后续按需扩字段。
@immutable
class TongtuTokens extends ThemeExtension<TongtuTokens> {
  const TongtuTokens({required this.buttonMinHeight});

  final double buttonMinHeight;

  @override
  TongtuTokens copyWith({double? buttonMinHeight}) =>
      TongtuTokens(buttonMinHeight: buttonMinHeight ?? this.buttonMinHeight);

  @override
  TongtuTokens lerp(ThemeExtension<TongtuTokens>? other, double t) {
    if (other is! TongtuTokens) return this;
    return TongtuTokens(
      buttonMinHeight:
          lerpDouble(buttonMinHeight, other.buttonMinHeight, t) ??
          buttonMinHeight,
    );
  }
}

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

  /// Button 样式层（三层方案 §6）：shape=`radius/full`、padding=`space/xl`、
  /// 文字=`label/large`、高度 40。样式集中在此，改一处全局生效，组件不写死。
  static final ButtonStyle _buttonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TongtuDimens.radiusFull),
      ),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: TongtuDimens.spaceXl),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(tongtuTextTheme.labelLarge),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 40)),
  );

  /// 组装主题：colorScheme + textTheme + Button component themes + 扩展 token。
  static ThemeData _theme(ColorScheme scheme) => ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: tongtuTextTheme,
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
    extensions: const <ThemeExtension<dynamic>>[
      TongtuTokens(buttonMinHeight: 40),
    ],
  );

  /// 浅色主题。
  static final ThemeData light = _theme(lightScheme);

  /// 深色主题。
  static final ThemeData dark = _theme(darkScheme);
}
