import 'dart:async';

import 'package:flutter/material.dart';

import '../core/clash_api.dart';
import '../core/core_controller.dart';

/// 监控页：实时流量速率（WS）+ 活动连接（REST 轮询）+ 日志流（WS）。
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key, required this.controller, this.apiFactory});

  final CoreController controller;

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new）。
  final ClashApi Function(ControllerEndpoint)? apiFactory;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  ClashApi? _api;
  StreamSubscription<Traffic>? _trafficSub;
  StreamSubscription<LogEntry>? _logSub;
  Timer? _connTimer;
  Traffic _traffic = const Traffic(up: 0, down: 0);
  List<ConnectionItem> _connections = <ConnectionItem>[];
  final List<LogEntry> _logs = <LogEntry>[];

  @override
  void initState() {
    super.initState();
    widget.controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      if (state == CoreState.connected) {
        _subscribe();
      } else {
        _unsubscribe();
      }
    });
    if (widget.controller.state == CoreState.connected) {
      _subscribe();
    }
  }

  void _subscribe() {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return;
    }
    final ClashApi api = _api ??= (widget.apiFactory ?? ClashApi.new)(endpoint);
    _trafficSub?.cancel();
    _trafficSub = api.trafficStream().listen((Traffic t) {
      if (mounted) {
        setState(() => _traffic = t);
      }
    }, onError: (_) {});
    _logSub?.cancel();
    _logSub = api.logsStream().listen((LogEntry e) {
      if (mounted) {
        setState(() {
          _logs.insert(0, e);
          if (_logs.length > 200) {
            _logs.removeLast();
          }
        });
      }
    }, onError: (_) {});
    _connTimer?.cancel();
    _connTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshConnections(),
    );
    _refreshConnections();
  }

  Future<void> _refreshConnections() async {
    final ClashApi? api = _api;
    if (api == null) {
      return;
    }
    try {
      final List<ConnectionItem> conns = await api.getConnections();
      if (mounted) {
        setState(() => _connections = conns);
      }
    } on Exception catch (_) {
      // 连接快照失败忽略，下次轮询重试
    }
  }

  void _unsubscribe() {
    _trafficSub?.cancel();
    _logSub?.cancel();
    _connTimer?.cancel();
    _trafficSub = null;
    _logSub = null;
    _connTimer = null;
    if (mounted) {
      setState(() {
        _traffic = const Traffic(up: 0, down: 0);
        _connections = <ConnectionItem>[];
        _logs.clear();
      });
    }
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _logSub?.cancel();
    _connTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.state != CoreState.connected) {
      return const Center(child: Text('请先在「连接」页连接'));
    }
    return Column(
      children: <Widget>[
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _rate('↑ 上行', _traffic.up),
                _rate('↓ 下行', _traffic.down),
                _stat('连接', '${_connections.length}'),
              ],
            ),
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: <Widget>[
                const TabBar(
                  tabs: <Widget>[
                    Tab(text: '连接'),
                    Tab(text: '日志'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[_buildConnections(), _buildLogs()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnections() {
    if (_connections.isEmpty) {
      return const Center(child: Text('暂无活动连接'));
    }
    return ListView.builder(
      itemCount: _connections.length,
      itemBuilder: (BuildContext context, int i) {
        final ConnectionItem conn = _connections[i];
        return ListTile(
          dense: true,
          title: Text(conn.host, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '${conn.chains.join(' → ')}　${conn.rule}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }

  Widget _buildLogs() {
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (BuildContext context, int i) {
        final LogEntry log = _logs[i];
        return ListTile(
          dense: true,
          leading: Text(log.type, style: const TextStyle(fontSize: 11)),
          title: Text(log.payload, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _rate(String label, int bytesPerSec) {
    return Column(
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          _formatRate(bytesPerSec),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  static String _formatRate(int bytesPerSec) {
    const List<String> units = <String>['B/s', 'KB/s', 'MB/s'];
    double value = bytesPerSec.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
