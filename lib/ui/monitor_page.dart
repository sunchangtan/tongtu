import 'dart:async';

import 'package:flutter/material.dart';

import '../core/clash_api.dart';
import '../core/core_controller.dart';
import '../util/format.dart';
import 'log_viewer_page.dart';

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
  StreamSubscription<CoreState>? _stateSub; // 状态流订阅，dispose 时取消防泄漏
  StreamSubscription<Traffic>? _trafficSub;
  StreamSubscription<LogEntry>? _logSub;
  Timer? _connTimer;
  Timer? _logFlushTimer;
  Traffic _traffic = const Traffic(up: 0, down: 0);
  List<ConnectionItem> _connections = <ConnectionItem>[];
  final List<LogEntry> _logs = <LogEntry>[]; // 内存最近 N 条（完整历史在落盘文件）
  final List<LogEntry> _pendingLogs = <LogEntry>[]; // 节流缓冲
  bool _logPaused = false;
  List<LogEntry>? _frozenLogs; // 暂停时的冻结快照
  static const int _logMemMax = 1000;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.controller.stateStream.listen((CoreState state) {
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
    // 节流：日志先入缓冲，由定时器批量刷新 UI（高频不卡顿）
    _logSub = api.logsStream().listen((LogEntry e) {
      _pendingLogs.add(e);
    }, onError: (_) {});
    _logFlushTimer?.cancel();
    _logFlushTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _flushLogs(),
    );
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

  /// 节流批量刷新：把缓冲日志并入内存列表（最新在顶），超上限丢最旧。
  /// 暂停时仍并入（不丢日志）但不刷 UI，继续后一次性显示。
  void _flushLogs() {
    if (_pendingLogs.isEmpty || !mounted) {
      return;
    }
    _logs.insertAll(0, _pendingLogs.reversed);
    _pendingLogs.clear();
    if (_logs.length > _logMemMax) {
      _logs.removeRange(_logMemMax, _logs.length);
    }
    if (!_logPaused) {
      setState(() {});
    }
  }

  /// 暂停/继续：暂停时冻结当前快照便于查看复制，底层仍接收不丢日志。
  void _toggleLogPause() {
    setState(() {
      _logPaused = !_logPaused;
      _frozenLogs = _logPaused ? List<LogEntry>.from(_logs) : null;
    });
  }

  void _unsubscribe() {
    _trafficSub?.cancel();
    _logSub?.cancel();
    _connTimer?.cancel();
    _logFlushTimer?.cancel();
    _trafficSub = null;
    _logSub = null;
    _connTimer = null;
    _logFlushTimer = null;
    _pendingLogs.clear();
    _frozenLogs = null;
    _logPaused = false;
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
    _stateSub?.cancel();
    _trafficSub?.cancel();
    _logSub?.cancel();
    _connTimer?.cancel();
    _logFlushTimer?.cancel();
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
    final List<LogEntry> logs = _logPaused ? (_frozenLogs ?? _logs) : _logs;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: 12),
            Text('共 ${logs.length} 条', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LogViewerPage()),
              ),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('完整'),
            ),
            TextButton.icon(
              onPressed: _toggleLogPause,
              icon: Icon(_logPaused ? Icons.play_arrow : Icons.pause, size: 18),
              label: Text(_logPaused ? '继续' : '暂停'),
            ),
          ],
        ),
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (BuildContext context, int i) {
                final LogEntry log = logs[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    '${_fmtTime(log.time)} [${log.type}] ${log.payload}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Widget _rate(String label, int bytesPerSec) {
    return Column(
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          formatRate(bytesPerSec),
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
}
