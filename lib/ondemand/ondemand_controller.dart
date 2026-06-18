import 'package:flutter/services.dart';

import 'ondemand_config.dart';

/// 按需连接的原生通道封装：下发配置、读取当前 Wi-Fi。
///
/// 复用内核控制 MethodChannel（`com.dingqi.tongtu/core`）。
class OnDemandController {
  OnDemandController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.dingqi.tongtu/core');

  final MethodChannel _channel;

  /// 下发按需连接配置到原生（即时持久化生效）。
  Future<void> update(OnDemandConfig config) async {
    await _channel.invokeMethod<void>('updateOnDemand', <String, dynamic>{
      'enabled': config.enabled,
      'scope': config.scope.name,
      'trustedSSIDs': config.trustedSSIDs,
    });
  }

  /// 读取当前 Wi-Fi SSID；权限被拒或无法获取时抛 [PlatformException]（含错误码）。
  Future<String?> currentSSID() {
    return _channel.invokeMethod<String>('currentSSID');
  }
}
