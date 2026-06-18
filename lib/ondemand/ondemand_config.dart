import 'package:flutter/foundation.dart';

/// 按需连接触发范围：决定在哪些网络接口上自动连接/断开。
enum OnDemandScope {
  /// 全部网络：任意接口均自动连接。
  all,

  /// 仅 WiFi：WiFi 下连接、蜂窝下断开。
  wifiOnly,

  /// 仅蜂窝：蜂窝下连接、WiFi 下断开。
  cellularOnly,
}

/// 按需连接统一语义配置（跨平台 UI 模型，分平台落地为各自的系统规则）。
///
/// 不可变值对象：增删信任 SSID、改触发范围等均经 [copyWith] 生成新实例。
@immutable
class OnDemandConfig {
  const OnDemandConfig({
    required this.enabled,
    required this.scope,
    required this.trustedSSIDs,
  });

  /// 缺省：关闭、触发范围「全部」、信任列表为空。
  const OnDemandConfig.defaults()
    : enabled = false,
      scope = OnDemandScope.all,
      trustedSSIDs = const <String>[];

  /// 从持久化 JSON 还原；缺字段回退缺省，未知 scope 回退 [OnDemandScope.all]。
  factory OnDemandConfig.fromJson(Map<String, dynamic> json) {
    return OnDemandConfig(
      enabled: json['enabled'] as bool? ?? false,
      scope: _scopeFromName(json['scope'] as String?),
      trustedSSIDs:
          (json['trustedSSIDs'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }

  /// 按需连接总开关。
  final bool enabled;

  /// 触发范围。
  final OnDemandScope scope;

  /// 信任 WiFi 列表：命中这些 SSID 时断开隧道（直连）。
  final List<String> trustedSSIDs;

  /// 序列化为持久化 JSON；scope 用枚举名（稳定字符串）。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'scope': scope.name,
    'trustedSSIDs': trustedSSIDs,
  };

  OnDemandConfig copyWith({
    bool? enabled,
    OnDemandScope? scope,
    List<String>? trustedSSIDs,
  }) {
    return OnDemandConfig(
      enabled: enabled ?? this.enabled,
      scope: scope ?? this.scope,
      trustedSSIDs: trustedSSIDs ?? this.trustedSSIDs,
    );
  }

  static OnDemandScope _scopeFromName(String? name) {
    for (final OnDemandScope s in OnDemandScope.values) {
      if (s.name == name) {
        return s;
      }
    }
    return OnDemandScope.all;
  }

  @override
  bool operator ==(Object other) =>
      other is OnDemandConfig &&
      other.enabled == enabled &&
      other.scope == scope &&
      listEquals(other.trustedSSIDs, trustedSSIDs);

  @override
  int get hashCode => Object.hash(enabled, scope, Object.hashAll(trustedSSIDs));
}
