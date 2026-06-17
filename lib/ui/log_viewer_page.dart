import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_store.dart';
import 'text_viewer_page.dart';

/// 完整日志回看页：复用通用 [TextViewerPage]（搜索/显示/复制），
/// 注入日志特有操作——刷新、导出（落盘文件或全文）、清空。
class LogViewerPage extends StatelessWidget {
  const LogViewerPage({super.key, this.store});

  /// 测试注入点。
  final LogStore? store;

  @override
  Widget build(BuildContext context) {
    final LogStore s = store ?? LogStore();
    return TextViewerPage(
      title: '完整日志',
      loader: s.readAll,
      searchHint: '搜索日志',
      actionsBuilder:
          (Future<void> Function() reload, String fullText) => <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: reload,
              tooltip: '刷新',
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () => _export(s, fullText),
              tooltip: '导出',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _clear(context, s, reload),
              tooltip: '清空',
            ),
          ],
    );
  }

  Future<void> _export(LogStore s, String fullText) async {
    final String? path = await s.currentLogFile();
    if (path != null) {
      await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(path)]));
    } else if (fullText.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(text: fullText));
    }
  }

  /// 清空全部落盘日志（含 backups），先弹确认防误删，清空后重载。
  Future<void> _clear(
    BuildContext context,
    LogStore s,
    Future<void> Function() reload,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('将删除全部落盘日志文件（含历史滚动文件），不可恢复。确定？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await s.clear();
    await reload();
  }
}
