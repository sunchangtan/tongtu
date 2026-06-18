import 'package:flutter/material.dart';

import '../tokens/tokens.g.dart';

/// 通途 Button 变体（中性命名，对齐 M3 与 Web/MUI variant 心智）。
/// 见 `docs/design/component-contract.md`。
enum TongtuButtonVariant { filled, tonal, outlined, text, elevated }

/// 通途 Button：薄 wrapper，按 variant 委托对应 M3 widget，并按 comp 单一入口显式取色。
///
/// comp 单一入口（见契约）：
/// - **颜色**按 variant + 明暗从 `comp/button/*`（`TongtuCompColors*`）显式取——
///   因 filled / tonal 共享 M3 `FilledButtonTheme`，色无法经 component theme 区分，
///   故在组件层给出；
/// - **结构尺寸 / 圆角 / 内距**经 `app_theme` 的 component theme 取自 `comp/button/*`
///   （`TongtuComp`），与本处色样式合并取用；
/// - **字体**走全局 type scale（`label/large`，非 comp，见契约边界）。
class TongtuButton extends StatelessWidget {
  const TongtuButton({
    super.key,
    required this.variant,
    required this.onPressed,
    required this.label,
    this.leadingIcon,
  });

  /// 视觉变体。
  final TongtuButtonVariant variant;

  /// 点击回调；为 null 时按钮 disabled（交互态由框架按 M3 处理）。
  final VoidCallback? onPressed;

  /// 文案。
  final String label;

  /// 可选前置图标。
  final Widget? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final Text child = Text(label);
    final bool hasIcon = leadingIcon != null;
    final ButtonStyle style = _styleFor(variant, Theme.of(context).brightness);
    switch (variant) {
      case TongtuButtonVariant.filled:
        return hasIcon
            ? FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leadingIcon!,
                label: child,
              )
            : FilledButton(onPressed: onPressed, style: style, child: child);
      case TongtuButtonVariant.tonal:
        return hasIcon
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                style: style,
                icon: leadingIcon!,
                label: child,
              )
            : FilledButton.tonal(
                onPressed: onPressed,
                style: style,
                child: child,
              );
      case TongtuButtonVariant.outlined:
        return hasIcon
            ? OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leadingIcon!,
                label: child,
              )
            : OutlinedButton(onPressed: onPressed, style: style, child: child);
      case TongtuButtonVariant.text:
        return hasIcon
            ? TextButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leadingIcon!,
                label: child,
              )
            : TextButton(onPressed: onPressed, style: style, child: child);
      case TongtuButtonVariant.elevated:
        return hasIcon
            ? ElevatedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leadingIcon!,
                label: child,
              )
            : ElevatedButton(onPressed: onPressed, style: style, child: child);
    }
  }
}

/// 按 variant + 明暗，从 `comp/button/*` 颜色构造仅含「色」的 `ButtonStyle`
/// （尺寸由 `app_theme` 的 component theme 提供，框架解析时合并）。
/// disabled 态用 `WidgetStateProperty` 取 comp disabled 色；hover / pressed 的
/// state layer 仍由框架按 foregroundColor 自动生成（不纳入 comp）。
ButtonStyle _styleFor(TongtuButtonVariant variant, Brightness brightness) {
  final bool dark = brightness == Brightness.dark;

  final Color label = switch (variant) {
    TongtuButtonVariant.filled => dark
        ? TongtuCompColorsDark.buttonFilledLabelColor
        : TongtuCompColorsLight.buttonFilledLabelColor,
    TongtuButtonVariant.tonal => dark
        ? TongtuCompColorsDark.buttonTonalLabelColor
        : TongtuCompColorsLight.buttonTonalLabelColor,
    TongtuButtonVariant.outlined => dark
        ? TongtuCompColorsDark.buttonOutlinedLabelColor
        : TongtuCompColorsLight.buttonOutlinedLabelColor,
    TongtuButtonVariant.text => dark
        ? TongtuCompColorsDark.buttonTextLabelColor
        : TongtuCompColorsLight.buttonTextLabelColor,
    TongtuButtonVariant.elevated => dark
        ? TongtuCompColorsDark.buttonElevatedLabelColor
        : TongtuCompColorsLight.buttonElevatedLabelColor,
  };

  final Color? container = switch (variant) {
    TongtuButtonVariant.filled => dark
        ? TongtuCompColorsDark.buttonFilledContainerColor
        : TongtuCompColorsLight.buttonFilledContainerColor,
    TongtuButtonVariant.tonal => dark
        ? TongtuCompColorsDark.buttonTonalContainerColor
        : TongtuCompColorsLight.buttonTonalContainerColor,
    TongtuButtonVariant.elevated => dark
        ? TongtuCompColorsDark.buttonElevatedContainerColor
        : TongtuCompColorsLight.buttonElevatedContainerColor,
    TongtuButtonVariant.outlined || TongtuButtonVariant.text => null,
  };

  final Color? outline = variant == TongtuButtonVariant.outlined
      ? (dark
            ? TongtuCompColorsDark.buttonOutlinedOutlineColor
            : TongtuCompColorsLight.buttonOutlinedOutlineColor)
      : null;

  final Color disabledLabel = dark
      ? TongtuCompColorsDark.buttonDisabledLabel
      : TongtuCompColorsLight.buttonDisabledLabel;
  final Color disabledContainer = dark
      ? TongtuCompColorsDark.buttonDisabledContainer
      : TongtuCompColorsLight.buttonDisabledContainer;
  final Color disabledOutline = dark
      ? TongtuCompColorsDark.buttonDisabledOutline
      : TongtuCompColorsLight.buttonDisabledOutline;

  final WidgetStateProperty<Color?> foreground =
      WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabledLabel : label,
      );

  WidgetStateProperty<Color?>? background;
  if (container != null) {
    final Color enabled = container;
    background = WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? disabledContainer : enabled,
    );
  }

  WidgetStateProperty<BorderSide?>? side;
  if (outline != null) {
    final Color enabled = outline;
    side = WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? disabledOutline
            : enabled,
        width: TongtuComp.buttonOutlineWidth,
      ),
    );
  }

  return ButtonStyle(
    backgroundColor: background,
    foregroundColor: foreground,
    side: side,
  );
}
