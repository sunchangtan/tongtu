import 'dart:math';

/// 运行时配置生成：以 metacubex 推荐模板为基础，合并订阅 proxy-providers，
/// 生成 mihomo 原生 YAML（不发明私有格式）。external-controller 端口/secret 随机生成。
class RuntimeConfig {
  /// 生成运行时 mihomo YAML：DNS fake-ip + 订阅 proxy-providers + 最小规则。
  /// external-controller / secret / gomemlimit 等由扩展侧 overrides 注入，不写入此 YAML。
  static String generateYAML({required String subscriptionUrl}) {
    return '''
mode: rule
log-level: warning
ipv6: false
dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver: [223.5.5.5, 8.8.8.8]
proxy-providers:
  default:
    type: http
    url: "$subscriptionUrl"
    interval: 86400
    path: ./providers/default.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
proxy-groups:
  - name: PROXY
    type: select
    use: [default]
rules:
  - MATCH,PROXY
''';
  }

  /// 随机 external-controller 端口（20000-59999，避开常用端口）。
  static int generatePort([Random? random]) {
    final Random rng = random ?? Random.secure();
    return 20000 + rng.nextInt(40000);
  }

  /// 随机 external-controller secret（32 位十六进制）。
  static String generateSecret([Random? random]) {
    final Random rng = random ?? Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
