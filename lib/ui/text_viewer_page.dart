import 'package:flutter/material.dart';

import 'safe_selection_toolbar.dart';

/// 通用只读文本查看页：加载文本 → 关键词搜索过滤 → SelectionArea 列表展示。
/// 标题、文本加载器、附加操作（刷新/导出/清空等）由调用方注入，供日志、订阅配置等复用，
/// 避免多处复制「读文本+搜索+复制」的相同逻辑。
class TextViewerPage extends StatefulWidget {
  const TextViewerPage({
    super.key,
    required this.title,
    required this.loader,
    this.searchHint = '搜索',
    this.unit = '行',
    this.emptyHint,
    this.actionsBuilder,
  });

  final String title;

  /// 文本加载器；返回 null 视为空。
  final Future<String?> Function() loader;
  final String searchHint;
  final String unit;

  /// 内容为空（且非加载中）时居中显示的提示；null 则不显示空态文案。
  final String? emptyHint;

  /// 附加 AppBar 操作构建器：`reload` 触发重载，`fullText` 为当前全文（供导出等）。
  final List<Widget> Function(Future<void> Function() reload, String fullText)?
  actionsBuilder;

  @override
  State<TextViewerPage> createState() => _TextViewerPageState();
}

class _TextViewerPageState extends State<TextViewerPage> {
  String _text = '';
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final String text = (await widget.loader()) ?? '';
    if (!mounted) {
      return;
    }
    setState(() {
      _text = text;
      _loading = false;
    });
  }

  List<String> get _lines {
    final List<String> all = _text
        .split('\n')
        .where((String l) => l.isNotEmpty)
        .toList();
    if (_query.isEmpty) {
      return all;
    }
    final String q = _query.toLowerCase();
    return all.where((String l) => l.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> lines = _lines;
    final bool showEmpty =
        lines.isEmpty && !_loading && widget.emptyHint != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actionsBuilder?.call(_load, _text),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
                '共 ${lines.length} ${widget.unit}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: showEmpty
                ? Center(child: Text(widget.emptyHint!))
                : SelectionArea(
                    contextMenuBuilder: safeSelectionContextMenu,
                    child: ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (BuildContext context, int i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            lines[i],
                            style: const TextStyle(fontSize: 12),
                          ),
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
