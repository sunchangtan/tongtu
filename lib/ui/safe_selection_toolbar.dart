import 'package:flutter/material.dart';

/// 安全计算文本选择工具栏锚点：包裹框架 [SelectableRegionState.contextMenuAnchors]，
/// 在其因 startSelectionPoint 为 null 抛 [TypeError] 时回退到给定锚点。
///
/// Flutter 3.44 框架缺陷：`SelectionArea` 包裹可滚动懒加载内容（`ListView.builder`）时，
/// 选择起点滚出视口被回收 → `startSelectionPoint` 为 null → `contextMenuAnchors` 内
/// `startGlyphHeight` 强解（`startSelectionPoint!`）崩溃。此回退使复制菜单仍可用、不崩。
TextSelectionToolbarAnchors resolveSafeAnchors(
  TextSelectionToolbarAnchors Function() compute,
  Offset fallback,
) {
  try {
    return compute();
  } on TypeError {
    return TextSelectionToolbarAnchors(primaryAnchor: fallback);
  }
}

/// 供 [SelectionArea.contextMenuBuilder] 复用的安全构建器：避开框架锚点崩溃。
///
/// 框架锚点可用时位置精确；不可用（geometry 起点为 null）时回退到内容区中心，
/// 复制等按钮仍可正常使用。
Widget safeSelectionContextMenu(
  BuildContext context,
  SelectableRegionState selectableRegionState,
) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  final Offset fallback = box != null
      ? box.localToGlobal(box.size.center(Offset.zero))
      : Offset.zero;
  final TextSelectionToolbarAnchors anchors = resolveSafeAnchors(
    () => selectableRegionState.contextMenuAnchors,
    fallback,
  );
  return AdaptiveTextSelectionToolbar.buttonItems(
    buttonItems: selectableRegionState.contextMenuButtonItems,
    anchors: anchors,
  );
}
