import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'text_viewer_page.dart';

/// 订阅配置原文查看页：只读展示当前订阅的完整配置正文，复用 [TextViewerPage]。
/// 展示的是**订阅原文**，不含内核运行时注入的覆写项（fake-ip / external-controller /
/// 运行参数偏好等）。正文来源由 [loader] 提供（连接首页的当前订阅 currentContent）。
class ConfigViewerPage extends StatelessWidget {
  const ConfigViewerPage({super.key, required this.loader});

  /// 配置正文加载器（返回 null/空表示尚无配置）。
  final Future<String?> Function() loader;

  @override
  Widget build(BuildContext context) {
    return TextViewerPage(
      title: '订阅配置',
      loader: loader,
      searchHint: '搜索配置',
      emptyHint: '尚无配置，请先在「订阅」页添加并选择订阅',
      actionsBuilder: (Future<void> Function() reload, String fullText) =>
          <Widget>[
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: '导出',
              onPressed: fullText.isEmpty
                  ? null
                  : () => SharePlus.instance.share(ShareParams(text: fullText)),
            ),
          ],
    );
  }
}
