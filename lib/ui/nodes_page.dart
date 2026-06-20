import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../core/clash_api.dart';
import '../core/core_controller.dart';

/// 节点页：展示 select 代理组节点、切换、延迟测试（长按）。
/// CoreController 由 HomeShell 注入；连接后用 currentEndpoint 构造 ClashApi。
/// 延迟测试 URL/超时取自 [runParams] 偏好（未注入则用默认）。
class NodesPage extends StatefulWidget {
  const NodesPage({
    super.key,
    required this.controller,
    this.runParams,
    this.apiFactory,
  });

  final CoreController controller;

  /// 运行参数偏好（提供延迟测试 URL/超时）；未注入时用默认值。
  final RunParamsStore? runParams;

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new）。
  final ClashApi Function(ControllerEndpoint)? apiFactory;

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  Map<String, ProxyGroup> _groups = <String, ProxyGroup>{};
  final Map<String, int> _delays = <String, int>{};
  bool _loading = false;
  String? _error;
  ClashApi? _api;

  @override
  void initState() {
    super.initState();
    widget.controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      if (state == CoreState.connected) {
        _refresh();
      } else {
        setState(() {
          _groups = <String, ProxyGroup>{};
          _error = null;
        });
      }
    });
    if (widget.controller.state == CoreState.connected) {
      _refresh();
    }
  }

  ClashApi? _ensureApi() {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return null;
    }
    return _api ??= (widget.apiFactory ?? ClashApi.new)(endpoint);
  }

  Future<void> _refresh() async {
    final ClashApi? api = _ensureApi();
    if (api == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, ProxyGroup> groups = await api.getProxyGroups();
      if (mounted) {
        setState(() => _groups = groups);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _select(String group, String name) async {
    final ClashApi? api = _ensureApi();
    if (api == null) {
      return;
    }
    try {
      await api.selectProxy(group, name);
      await _refresh();
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _testDelay(String name) async {
    final ClashApi? api = _ensureApi();
    if (api == null) {
      return;
    }
    try {
      final RunParams p = widget.runParams?.params ?? const RunParams();
      final int delay = await api.testDelay(
        name,
        url: p.delayTestUrl,
        timeout: p.delayTestTimeoutMs,
      );
      if (mounted) {
        setState(() => _delays[name] = delay);
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _delays[name] = -1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.state != CoreState.connected) {
      return const Center(child: Text('请先在「连接」页连接'));
    }
    if (_loading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _groups.isEmpty) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        children: <Widget>[
          for (final ProxyGroup group in _groups.values) _buildGroup(group),
        ],
      ),
    );
  }

  Widget _buildGroup(ProxyGroup group) {
    return ExpansionTile(
      title: Text(group.name),
      subtitle: Text('当前：${group.now}'),
      initiallyExpanded: true,
      children: <Widget>[
        for (final String node in group.all)
          ListTile(
            title: Text(node),
            leading: Icon(
              node == group.now
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            trailing: _delayLabel(node),
            onTap: () => _select(group.name, node),
            onLongPress: () => _testDelay(node),
          ),
      ],
    );
  }

  Widget? _delayLabel(String node) {
    final int? delay = _delays[node];
    if (delay == null) {
      return null;
    }
    if (delay < 0) {
      return const Text(
        '超时',
        style: TextStyle(color: Colors.red, fontSize: 12),
      );
    }
    return Text('$delay ms', style: const TextStyle(fontSize: 12));
  }
}
