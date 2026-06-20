import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// 运行参数偏好（对齐 clashmi 核心设置中 iOS NE 适用项）。值类型、含默认值。
/// 延迟测试 URL/超时为 app 侧参数（节点测延迟用），不写入内核配置。
class RunParams {
  const RunParams({
    this.mode = 'rule',
    this.logLevel = 'info',
    this.ipv6 = false,
    this.unifiedDelay = true,
    this.tcpConcurrent = true,
    this.sniff = false,
    this.allowLan = false,
    this.mixedPort = 7890,
    this.delayTestUrl = 'http://www.gstatic.com/generate_204',
    this.delayTestTimeoutMs = 5000,
  });

  final String mode; // rule / global / direct
  final String logLevel; // silent / error / warning / info / debug
  final bool ipv6;
  final bool unifiedDelay;
  final bool tcpConcurrent;
  final bool sniff; // 域名嗅探
  final bool allowLan; // 局域网接入（与 mixedPort 成对做局域网代理共享）
  final int mixedPort;
  final String delayTestUrl; // app 侧：节点测延迟
  final int delayTestTimeoutMs; // app 侧

  RunParams copyWith({
    String? mode,
    String? logLevel,
    bool? ipv6,
    bool? unifiedDelay,
    bool? tcpConcurrent,
    bool? sniff,
    bool? allowLan,
    int? mixedPort,
    String? delayTestUrl,
    int? delayTestTimeoutMs,
  }) {
    return RunParams(
      mode: mode ?? this.mode,
      logLevel: logLevel ?? this.logLevel,
      ipv6: ipv6 ?? this.ipv6,
      unifiedDelay: unifiedDelay ?? this.unifiedDelay,
      tcpConcurrent: tcpConcurrent ?? this.tcpConcurrent,
      sniff: sniff ?? this.sniff,
      allowLan: allowLan ?? this.allowLan,
      mixedPort: mixedPort ?? this.mixedPort,
      delayTestUrl: delayTestUrl ?? this.delayTestUrl,
      delayTestTimeoutMs: delayTestTimeoutMs ?? this.delayTestTimeoutMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode,
    'logLevel': logLevel,
    'ipv6': ipv6,
    'unifiedDelay': unifiedDelay,
    'tcpConcurrent': tcpConcurrent,
    'sniff': sniff,
    'allowLan': allowLan,
    'mixedPort': mixedPort,
    'delayTestUrl': delayTestUrl,
    'delayTestTimeoutMs': delayTestTimeoutMs,
  };

  factory RunParams.fromJson(Map<String, dynamic> j) {
    const RunParams d = RunParams();
    return RunParams(
      mode: j['mode'] as String? ?? d.mode,
      logLevel: j['logLevel'] as String? ?? d.logLevel,
      ipv6: j['ipv6'] as bool? ?? d.ipv6,
      unifiedDelay: j['unifiedDelay'] as bool? ?? d.unifiedDelay,
      tcpConcurrent: j['tcpConcurrent'] as bool? ?? d.tcpConcurrent,
      sniff: j['sniff'] as bool? ?? d.sniff,
      allowLan: j['allowLan'] as bool? ?? d.allowLan,
      mixedPort: j['mixedPort'] as int? ?? d.mixedPort,
      delayTestUrl: j['delayTestUrl'] as String? ?? d.delayTestUrl,
      delayTestTimeoutMs:
          j['delayTestTimeoutMs'] as int? ?? d.delayTestTimeoutMs,
    );
  }
}

/// 运行参数偏好存储（ChangeNotifier + shared_prefs）。与订阅正交，随时可设。
/// 连接时经 [applyToConfig] 把偏好合并进订阅配置 YAML（顶层键，重连生效）。
class RunParamsStore extends ChangeNotifier {
  static const String _key = 'run_params';

  RunParams _params = const RunParams();
  bool _hasPersisted = false; // 是否已有持久化偏好（决定是否种子化）

  RunParams get params => _params;

  /// 加载持久化偏好；无则取默认（不在此种子化，种子化需配置另调 [seedFromConfig]）。
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw != null) {
      _hasPersisted = true;
      try {
        _params = RunParams.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _params = const RunParams(); // 损坏 JSON 退默认
      }
    } else {
      _hasPersisted = false;
      _params = const RunParams();
    }
    notifyListeners();
  }

  /// 保存偏好（持久化 + 通知）。
  Future<void> save(RunParams p) async {
    _params = p;
    await _persist();
    notifyListeners();
  }

  /// 升级种子化：仅当尚无持久化偏好时，从当前订阅配置顶层键读初值，避免默认值
  /// 覆盖既有用户配置。返回是否执行了种子化；幂等（已持久化则 no-op）。
  Future<bool> seedFromConfig(String yaml) async {
    if (_hasPersisted) {
      return false;
    }
    const RunParams d = RunParams();
    RunParams seeded = d;
    try {
      final dynamic doc = loadYaml(yaml);
      if (doc is Map) {
        seeded = RunParams(
          mode: _str(doc['mode'], d.mode),
          logLevel: _str(doc['log-level'], d.logLevel),
          ipv6: _bool(doc['ipv6'], d.ipv6),
          unifiedDelay: _bool(doc['unified-delay'], d.unifiedDelay),
          tcpConcurrent: _bool(doc['tcp-concurrent'], d.tcpConcurrent),
          sniff: _bool((doc['sniffer'] as Map?)?['enable'], d.sniff),
          allowLan: _bool(doc['allow-lan'], d.allowLan),
          mixedPort: _int(doc['mixed-port'], d.mixedPort),
          // delay-test（app 侧）不在内核配置中，取默认
        );
      }
    } catch (_) {
      seeded = d; // 配置解析失败用默认
    }
    _params = seeded;
    await _persist();
    notifyListeners();
    return true;
  }

  /// 把偏好合并进配置 YAML 顶层键（存在改写、不存在新增，保留其余内容）。
  /// 非法/非 map 配置不破坏、原样返回（连接时内核 Start 终校验兜底）。
  String applyToConfig(String yaml) {
    try {
      final YamlEditor editor = YamlEditor(yaml);
      editor.update(<String>['mode'], _params.mode);
      editor.update(<String>['log-level'], _params.logLevel);
      editor.update(<String>['ipv6'], _params.ipv6);
      editor.update(<String>['unified-delay'], _params.unifiedDelay);
      editor.update(<String>['tcp-concurrent'], _params.tcpConcurrent);
      editor.update(<String>['allow-lan'], _params.allowLan);
      editor.update(<String>['mixed-port'], _params.mixedPort);
      editor.update(<String>['sniffer'], _snifferBlock(_params.sniff));
      return editor.toString();
    } catch (_) {
      return yaml;
    }
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_params.toJson()));
    _hasPersisted = true;
  }

  /// 最小 sniffer 段：开启时嗅探 HTTP/TLS/QUIC 常见端口，便于 TUN 下按域名分流。
  static Map<String, dynamic> _snifferBlock(bool enable) {
    if (!enable) {
      return <String, dynamic>{'enable': false};
    }
    return <String, dynamic>{
      'enable': true,
      'sniff': <String, dynamic>{
        'HTTP': <String, dynamic>{
          'ports': <dynamic>[80, '8080-8880'],
        },
        'TLS': <String, dynamic>{
          'ports': <dynamic>[443, '8443'],
        },
        'QUIC': <String, dynamic>{
          'ports': <dynamic>[443, '8443'],
        },
      },
      'override-destination': false,
    };
  }

  static String _str(dynamic v, String dflt) => v is String ? v : dflt;
  static bool _bool(dynamic v, bool dflt) => v is bool ? v : dflt;
  static int _int(dynamic v, int dflt) => v is int ? v : dflt;
}
