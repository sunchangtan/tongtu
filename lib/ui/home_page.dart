import 'dart:async';

import 'package:flutter/material.dart';

import '../config/runtime_config.dart';
import '../config/subscription.dart';
import '../core/core_controller.dart';

/// 连接页：获取配置（拉取订阅验证）、连接/断开、隧道状态与内存指标显示。
/// CoreController 由 HomeShell 持有并注入（多页共享同一实例）。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final CoreController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CoreController _controller;
  final SubscriptionStore _subscriptions = SubscriptionStore();
  final TextEditingController _urlController = TextEditingController();
  CoreState _state = CoreState.stopped;
  bool _fetching = false;
  SubscriptionInfo? _info;
  MemorySnapshot? _memory;
  Timer? _memoryTimer;
  Timer? _connectTimer;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _urlController.addListener(_onUrlChanged);
    _controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      setState(() => _state = state);
      if (state == CoreState.connected) {
        _connectTimer?.cancel();
        _startMemoryPolling();
      } else {
        _stopMemoryPolling();
      }
    });
    _loadSubscription();
  }

  void _onUrlChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canFetch =>
      SubscriptionStore.isValidUrl(_urlController.text) && !_fetching;

  bool get _canConnect =>
      SubscriptionStore.isValidUrl(_urlController.text) &&
      _state != CoreState.connected &&
      _state != CoreState.connecting;

  Future<void> _loadSubscription() async {
    final String? url = await _subscriptions.load();
    if (url != null && mounted) {
      _urlController.text = url;
    }
  }

  void _startMemoryPolling() {
    _memoryTimer?.cancel();
    _memoryTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final MemorySnapshot? snapshot = await _controller.memorySnapshot();
      if (mounted) {
        setState(() => _memory = snapshot);
      }
    });
  }

  void _stopMemoryPolling() {
    _memoryTimer?.cancel();
    _memoryTimer = null;
    if (mounted) {
      setState(() => _memory = null);
    }
  }

  /// 连接超时检测：15 秒未建立隧道则读取扩展诊断（内核启动失败原因）并提示。
  void _scheduleConnectTimeout() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 15), () async {
      if (!mounted || _state == CoreState.connected) {
        return;
      }
      final String diag = await _controller.lastResult();
      if (mounted) {
        setState(() {
          _message = diag.isNotEmpty ? diag : '连接超时（15 秒未建立隧道）';
        });
      }
    });
  }

  Future<void> _fetchConfig() async {
    setState(() {
      _fetching = true;
      _message = null;
      _info = null;
    });
    try {
      await _subscriptions.save(_urlController.text);
      final SubscriptionInfo info = await _subscriptions.fetch(
        _urlController.text,
      );
      if (mounted) {
        setState(() => _info = info);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _message = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _message = null);
    try {
      await _subscriptions.save(_urlController.text);
      final String url = _urlController.text.trim();
      await _controller.start(
        configYAML: RuntimeConfig.generateYAML(subscriptionUrl: url),
      );
      _scheduleConnectTimeout();
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _message = e.toString());
      }
    }
  }

  Future<void> _disconnect() async {
    _connectTimer?.cancel();
    await _controller.stop();
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _memoryTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '订阅链接',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _canFetch ? _fetchConfig : null,
            icon: _fetching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            label: Text(_fetching ? '获取中…' : '获取配置'),
          ),
          if (_info != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildInfoCard(_info!),
          ],
          const SizedBox(height: 16),
          Text('状态：${_stateText(_state)}'),
          if (_memory != null) ...<Widget>[
            const SizedBox(height: 8),
            _buildMemoryCard(_memory!),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _canConnect ? _connect : null,
                  child: const Text('连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _state == CoreState.stopped ? null : _disconnect,
                  child: const Text('断开'),
                ),
              ),
            ],
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(_message!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(SubscriptionInfo info) {
    final List<String> lines = <String>[];
    final int? total = info.total;
    if (total != null) {
      final int used = (info.upload ?? 0) + (info.download ?? 0);
      lines.add('流量：${_formatBytes(used)} / ${_formatBytes(total)}');
    }
    final int? expire = info.expire;
    if (expire != null && expire > 0) {
      lines.add('到期：${_formatExpire(expire)}');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  info.ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: info.ok ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(info.message ?? (info.ok ? '订阅可达' : '获取失败')),
                ),
              ],
            ),
            for (final String line in lines) ...<Widget>[
              const SizedBox(height: 4),
              Text(line, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(MemorySnapshot memory) {
    final double footprintMiB = memory.footprintBytes / 1024 / 1024;
    final double goHeapMiB = memory.goHeapBytes / 1024 / 1024;
    final bool warn = footprintMiB >= 40;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Footprint：${footprintMiB.toStringAsFixed(1)} MiB（红线 50 / 常驻 40）',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: warn ? Colors.orange : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '内核 Go 堆：${goHeapMiB.toStringAsFixed(1)} MiB',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateText(CoreState state) {
    switch (state) {
      case CoreState.stopped:
        return '未连接';
      case CoreState.connecting:
        return '连接中…';
      case CoreState.connected:
        return '已连接';
      case CoreState.error:
        return '错误';
    }
  }

  static String _formatBytes(int bytes) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
  }

  static String _formatExpire(int unixSeconds) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
    );
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
