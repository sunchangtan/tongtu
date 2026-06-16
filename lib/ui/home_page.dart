import 'package:flutter/material.dart';

import '../config/runtime_config.dart';
import '../config/subscription.dart';
import '../core/apple_core_controller.dart';
import '../core/core_controller.dart';

/// M1 最小连接界面：导入订阅、连接/断开、隧道状态显示。
class HomePage extends StatefulWidget {
  const HomePage({super.key, CoreController? controller})
    : _injectedController = controller;

  final CoreController? _injectedController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CoreController _controller;
  final SubscriptionStore _subscriptions = SubscriptionStore();
  final TextEditingController _urlController = TextEditingController();
  CoreState _state = CoreState.stopped;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = widget._injectedController ?? AppleCoreController();
    _controller.stateStream.listen((CoreState state) {
      if (mounted) {
        setState(() => _state = state);
      }
    });
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final String? url = await _subscriptions.load();
    if (url != null && mounted) {
      _urlController.text = url;
    }
  }

  Future<void> _connect() async {
    setState(() => _message = null);
    try {
      await _subscriptions.save(_urlController.text);
      final String url = _urlController.text.trim();
      await _controller.start(
        configYAML: RuntimeConfig.generateYAML(subscriptionUrl: url),
        controllerPort: RuntimeConfig.generatePort(),
        controllerSecret: RuntimeConfig.generateSecret(),
      );
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _message = e.toString());
      }
    }
  }

  Future<void> _disconnect() async {
    await _controller.stop();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通途')),
      body: Padding(
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
            const SizedBox(height: 16),
            Text('状态：${_stateText(_state)}'),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _state == CoreState.connected ? null : _connect,
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
