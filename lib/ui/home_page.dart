import 'dart:async';

import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../config/subscriptions_store.dart';
import '../core/core_controller.dart';
import 'run_mode_selector.dart';
import 'safe_selection_toolbar.dart';

/// 连接页（连接 tab 内首子页）：运行模式、连接/断开、隧道状态与内存指标、诊断。
/// 订阅管理已独立到「订阅」tab；连接使用当前选中订阅的配置正文（[SubscriptionsStore.currentContent]），
/// 并在启动前合并运行参数偏好（[RunParamsStore.applyToConfig]）。
/// CoreController / SubscriptionsStore / RunParamsStore 均由上层持有并注入（多页共享同一实例）。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.store,
    required this.runParams,
  });

  final CoreController controller;
  final SubscriptionsStore store;
  final RunParamsStore runParams;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CoreController _controller;
  late final SubscriptionsStore _store;
  CoreState _state = CoreState.stopped;
  MemorySnapshot? _memory;
  Timer? _memoryTimer;
  Timer? _connectTimer;
  String? _message;
  String? _diag;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _store = widget.store;
    // 监听订阅变化：订阅 tab 增删/切换当前后，连接按钮启用状态即时刷新（跨页同步）。
    _store.addListener(_onStoreChanged);
    _controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
        if (state != CoreState.connected) {
          _diag = null;
        }
      });
      if (state == CoreState.connected) {
        _connectTimer?.cancel();
        _startMemoryPolling();
        _loadDiag();
      } else {
        _stopMemoryPolling();
      }
    });
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasCurrent => _store.currentId != null;

  bool get _canConnect =>
      _hasCurrent &&
      _state != CoreState.connected &&
      _state != CoreState.connecting;

  /// 诊断：连接后读取内核启动结果（经 App Group 共享，不走有问题的 loopback），
  /// 用于真机定位数据通路问题（内核是否启动、tunFD、运行状态）。
  Future<void> _loadDiag() async {
    final String diag = await _controller.lastResult();
    if (mounted) {
      setState(() => _diag = diag);
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

  Future<void> _connect() async {
    setState(() => _message = null);
    try {
      // 用当前选中订阅的完整 clash 配置正文作为内核主配置
      final String? content = await _store.currentContent();
      if (content == null || content.isEmpty) {
        if (mounted) {
          setState(() => _message = '请先在订阅页添加并选择订阅');
        }
        return;
      }
      // 启动前合并运行参数偏好（顶层键写入配置，重连生效）
      final String merged = widget.runParams.applyToConfig(content);
      await _controller.start(configYAML: merged);
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
    _store.removeListener(_onStoreChanged); // 不 dispose store（上层共享持有）
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SelectionArea 统一托管文本选择：错误提示等可选中复制，点击空白处自动取消选择。
    return SelectionArea(
      contextMenuBuilder: safeSelectionContextMenu,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            RunModeSelector(
              controller: _controller,
              runParams: widget.runParams,
            ),
            const SizedBox(height: 16),
            Text('状态：${_stateText(_state)}'),
            if (_memory != null) ...<Widget>[
              const SizedBox(height: 8),
              _buildMemoryCard(_memory!),
            ],
            const SizedBox(height: 16),
            _buildActionButton(),
            if (!_hasCurrent) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                '请先在订阅页添加并选择订阅',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
            if (_diag != null && _diag!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '主App端口：${_controller.currentEndpoint?.port ?? "?"}\n内核诊断：${_diag!}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(_message!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  /// 单一动作按钮：未连接显示「连接」（无当前订阅则禁用），连接中/已连接显示「断开」。
  Widget _buildActionButton() {
    final bool active =
        _state == CoreState.connected || _state == CoreState.connecting;
    if (active) {
      return FilledButton.tonal(
        onPressed: _disconnect,
        child: Text(_state == CoreState.connecting ? '连接中…（取消）' : '断开'),
      );
    }
    return FilledButton(
      onPressed: _canConnect ? _connect : null,
      child: const Text('连接'),
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
}
