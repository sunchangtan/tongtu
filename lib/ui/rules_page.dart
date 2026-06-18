import 'package:flutter/material.dart';

import '../core/clash_api.dart';
import '../core/core_controller.dart';
import 'safe_selection_toolbar.dart';

/// 分流规则查看页：内核运行时经 clash-api 取当前生效规则，列表 + 搜索 + 空态。
class RulesPage extends StatefulWidget {
  const RulesPage({super.key, required this.controller, this.apiFactory});

  final CoreController controller;

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new）。
  final ClashApi Function(ControllerEndpoint)? apiFactory;

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  ClashApi? _api;
  List<RuleItem> _rules = <RuleItem>[];
  String _query = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.controller.state == CoreState.connected) {
      _load();
    }
  }

  @override
  void dispose() {
    _api?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ClashApi api = _api ??= (widget.apiFactory ?? ClashApi.new)(
        endpoint,
      );
      final List<RuleItem> rules = await api.getRules();
      if (mounted) {
        setState(() {
          _rules = rules;
          _loading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载规则失败：${e.runtimeType}';
          _loading = false;
        });
      }
    }
  }

  List<RuleItem> get _filtered {
    if (_query.isEmpty) {
      return _rules;
    }
    final String q = _query.toLowerCase();
    return _rules.where((RuleItem r) {
      return r.payload.toLowerCase().contains(q) ||
          r.proxy.toLowerCase().contains(q) ||
          r.type.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = widget.controller.state == CoreState.connected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('分流规则'),
        actions: <Widget>[
          if (connected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: '刷新',
            ),
        ],
      ),
      body: connected
          ? _buildList()
          : const Center(child: Text('请先在「连接」页连接后查看生效规则')),
    );
  }

  Widget _buildList() {
    final List<RuleItem> rules = _filtered;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索规则',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '共 ${rules.length} 条',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: rules.isEmpty && !_loading
              ? const Center(child: Text('暂无规则'))
              : SelectionArea(
                  contextMenuBuilder: safeSelectionContextMenu,
                  child: ListView.builder(
                    itemCount: rules.length,
                    itemBuilder: (BuildContext context, int i) {
                      final RuleItem r = rules[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${r.type}  ${r.payload}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '→ ${r.proxy}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
