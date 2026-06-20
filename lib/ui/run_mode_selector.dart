import 'dart:async';

import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../core/clash_api.dart';
import '../core/core_controller.dart';

const List<String> _modes = <String>['rule', 'global', 'direct'];

/// 运行模式选择器（连接首页）：store 驱动的预设偏好——**未连接也可改**（存为偏好、
/// 重连生效）；**连接中改则即时热切**（`PATCH /configs`）并同步偏好。对齐 clashmi：
/// 运行模式既是仪表盘可热切项，也是可预设偏好。
class RunModeSelector extends StatefulWidget {
  const RunModeSelector({
    super.key,
    required this.controller,
    required this.runParams,
    this.apiFactory,
  });

  final CoreController controller;
  final RunParamsStore runParams;

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new）。
  final ClashApi Function(ControllerEndpoint)? apiFactory;

  @override
  State<RunModeSelector> createState() => _RunModeSelectorState();
}

class _RunModeSelectorState extends State<RunModeSelector> {
  StreamSubscription<CoreState>? _stateSub; // dispose 取消，防泄漏
  ClashApi? _api;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      setState(() => _connected = state == CoreState.connected);
      if (state != CoreState.connected) {
        _api?.dispose();
        _api = null;
      }
    });
    if (widget.controller.state == CoreState.connected) {
      _connected = true;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _api?.dispose();
    super.dispose();
  }

  ClashApi? _ensureApi() {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return null;
    }
    return _api ??= (widget.apiFactory ?? ClashApi.new)(endpoint);
  }

  /// 改运行模式：存为偏好（重连生效）；若连接中则同时 `PATCH /configs` 即时热切。
  Future<void> _change(String mode) async {
    await widget.runParams.save(widget.runParams.params.copyWith(mode: mode));
    if (!_connected) {
      return;
    }
    final ClashApi? api = _ensureApi();
    if (api == null) {
      return;
    }
    try {
      await api.patchConfigs(<String, dynamic>{'mode': mode});
    } on Exception catch (e) {
      // on Exception：断连时底层抛 SocketException 等；偏好已存，重连即生效
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('热切失败（已存偏好，重连生效）：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.runParams,
      builder: (BuildContext context, Widget? _) {
        final String mode = widget.runParams.params.mode;
        final String safeMode = _modes.contains(mode) ? mode : 'rule';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('运行模式', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'rule', label: Text('规则')),
                ButtonSegment<String>(value: 'global', label: Text('全局')),
                ButtonSegment<String>(value: 'direct', label: Text('直连')),
              ],
              selected: <String>{safeMode},
              onSelectionChanged: (Set<String> s) => _change(s.first),
            ),
          ],
        );
      },
    );
  }
}
