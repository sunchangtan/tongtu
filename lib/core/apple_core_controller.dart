import 'dart:async';

import 'package:flutter/services.dart';

import 'core_controller.dart';

/// 苹果平台 CoreController 实现：经 Platform Channel 与原生层通信，
/// 由原生层通过 NETunnelProviderManager 控制 Packet Tunnel 扩展启停，
/// 隧道状态经事件通道回传 Dart。
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

  @override
  Stream<CoreState> get stateStream => _stateController.stream;

  @override
  CoreState get state => _state;

  @override
  Future<void> start({
    required String configYAML,
    required int controllerPort,
    required String controllerSecret,
  }) {
    return _method.invokeMethod<void>('start', <String, dynamic>{
      'config': configYAML,
      'port': controllerPort,
      'secret': controllerSecret,
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

  /// 释放事件订阅与状态流。
  Future<void> dispose() async {
    await _subscription.cancel();
    await _stateController.close();
  }
}
