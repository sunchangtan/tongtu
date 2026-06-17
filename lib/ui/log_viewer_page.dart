import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_store.dart';

/// 完整日志回看页：从落盘文件读全量日志（含内核启动最早段、跨会话），
/// 支持搜索、刷新、导出分享。完整历史以落盘文件为准。
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key, this.store});

  /// 测试注入点。
  final LogStore? store;

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  late final LogStore _store = widget.store ?? LogStore();
  List<String> _allLines = <String>[];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final String content = await _store.readAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _allLines = content
          .split('\n')
          .where((String l) => l.isNotEmpty)
          .toList();
      _loading = false;
    });
  }

  Future<void> _export() async {
    final String? path = await _store.currentLogFile();
    if (path != null) {
      await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(path)]));
    } else if (_allLines.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(text: _allLines.join('\n')));
    }
  }

  /// 清空全部落盘日志（含 backups），先弹确认防误删，清空后重载。
  Future<void> _clear() async {
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
    await _store.clear();
    if (!mounted) {
      return;
    }
    await _load();
  }

  List<String> get _filtered {
    if (_query.isEmpty) {
      return _allLines;
    }
    final String q = _query.toLowerCase();
    return _allLines.where((String l) => l.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> lines = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('完整日志'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
            tooltip: '导出',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
            tooltip: '清空',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索日志',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '共 ${lines.length} 行',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (BuildContext context, int i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Text(lines[i], style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
