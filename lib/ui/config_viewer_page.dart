import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/subscription.dart';
import 'text_viewer_page.dart';

/// 订阅配置原文查看页：只读展示订阅下载的完整配置正文，复用 [TextViewerPage]。
/// 展示的是**订阅原文**，不含内核运行时注入的覆写项（fake-ip / external-controller 等）。
class ConfigViewerPage extends StatelessWidget {
  const ConfigViewerPage({super.key, this.store});

  /// 测试注入点。
  final SubscriptionStore? store;

  @override
  Widget build(BuildContext context) {
    final SubscriptionStore s = store ?? SubscriptionStore();
    return TextViewerPage(
      title: '订阅配置',
      loader: s.loadContent,
      searchHint: '搜索配置',
      emptyHint: '尚未获取配置，请先在「连接」页获取配置',
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
