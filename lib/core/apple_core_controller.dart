import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

import 'core_controller.dart';

/// 苹果平台 CoreController 实现：经 Platform Channel 与原生层通信，
/// 由原生层通过 NETunnelProviderManager 控制 Packet Tunnel 扩展启停，
/// 隧道状态经事件通道回传 Dart。external-controller 端口/secret 在 start 内部
/// 随机生成并持有（供 clash-api 复用），同时注入扩展。
class AppleCoreController implements CoreController {
  AppleCoreController({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method = methodChannel ?? const MethodChannel(_methodName),
      _events = eventChannel ?? const EventChannel(_eventName) {
    _subscription = _events.receiveBroadcastStream().listen(_onNativeState);
  }

  static const String _methodName = 'com.dingqi.tongtu/core';
  static const String _eventName = 'com.dingqi.tongtu/core_state';

  final MethodChannel _method;
  final EventChannel _events;
  late final StreamSubscription<dynamic> _subscription;
  final StreamController<CoreState> _stateController =
      StreamController<CoreState>.broadcast();
  CoreState _state = CoreState.stopped;
  ControllerEndpoint? _endpoint;

  @override
  Stream<CoreState> get stateStream => _stateController.stream;

  @override
  CoreState get state => _state;

  @override
  ControllerEndpoint? get currentEndpoint => _endpoint;

  @override
  Future<void> start({required String configYAML}) {
    final ControllerEndpoint endpoint = ControllerEndpoint(
      host: '127.0.0.1',
      port: _randomPort(),
      secret: _randomSecret(),
    );
    _endpoint = endpoint;
    return _method.invokeMethod<void>('start', <String, dynamic>{
      'config': configYAML,
      'port': endpoint.port,
      'secret': endpoint.secret,
    });
  }

  @override
  Future<void> stop() => _method.invokeMethod<void>('stop');

  @override
  Future<MemorySnapshot?> memorySnapshot() async {
    final Map<dynamic, dynamic>? raw =
        await _method.invokeMapMethod<dynamic, dynamic>('memory');
    if (raw == null) {
      return null;
    }
    return MemorySnapshot(
      footprintBytes: (raw['footprint'] as num?)?.toInt() ?? 0,
      goHeapBytes: (raw['goHeap'] as num?)?.toInt() ?? 0,
      ageSeconds: (raw['age'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<String> lastResult() async {
    final String? result = await _method.invokeMethod<String>('lastResult');
    return result ?? '';
  }

  void _onNativeState(dynamic event) {
    final CoreState? next = _parseState(event);
    if (next != null) {
      _state = next;
      _stateController.add(next);
    }
  }

  static CoreState? _parseState(dynamic raw) {
    switch (raw) {
      case 'stopped':
        return CoreState.stopped;
      case 'connecting':
        return CoreState.connecting;
      case 'connected':
        return CoreState.connected;
      case 'error':
        return CoreState.error;
      default:
        return null;
    }
  }

  /// 随机 external-controller 端口（20000-59999，避开常用端口）。
  static int _randomPort([Random? random]) {
    final Random rng = random ?? Random.secure();
    return 20000 + rng.nextInt(40000);
  }

  /// 随机 external-controller secret（32 位十六进制）。
  static String _randomSecret([Random? random]) {
    final Random rng = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 释放事件订阅与状态流。
  Future<void> dispose() async {
    await _subscription.cancel();
    await _stateController.close();
  }
}
