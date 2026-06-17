import 'package:flutter/material.dart';

/// 通途 Button 变体（中性命名，对齐 M3 与 Web/MUI variant 心智）。
/// 见 `docs/design/component-contract.md`。
enum TongtuButtonVariant { filled, tonal, outlined, text, elevated }

/// 通途 Button：薄 wrapper，按 variant 委托对应 M3 widget。
///
/// 三层方案（见契约 §6）：样式来自 `ThemeData` 的 component themes（`app_theme`），
/// 此处**不写死样式**，只负责「选 widget + 摆 icon/label」+ 统一 variant API + 扩展点。
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
    switch (variant) {
      case TongtuButtonVariant.filled:
        return hasIcon
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: leadingIcon!,
                label: child,
              )
            : FilledButton(onPressed: onPressed, child: child);
      case TongtuButtonVariant.tonal:
        return hasIcon
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: leadingIcon!,
                label: child,
              )
            : FilledButton.tonal(onPressed: onPressed, child: child);
      case TongtuButtonVariant.outlined:
        return hasIcon
            ? OutlinedButton.icon(
                onPressed: onPressed,
                icon: leadingIcon!,
                label: child,
              )
            : OutlinedButton(onPressed: onPressed, child: child);
      case TongtuButtonVariant.text:
        return hasIcon
            ? TextButton.icon(
                onPressed: onPressed,
                icon: leadingIcon!,
                label: child,
              )
            : TextButton(onPressed: onPressed, child: child);
      case TongtuButtonVariant.elevated:
        return hasIcon
            ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: leadingIcon!,
                label: child,
              )
            : ElevatedButton(onPressed: onPressed, child: child);
    }
  }
}
