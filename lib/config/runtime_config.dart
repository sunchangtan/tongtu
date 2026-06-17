/// 运行时配置生成：以 metacubex 推荐模板为基础，合并订阅 proxy-providers，
/// 生成 mihomo 原生 YAML（不发明私有格式）。
///
/// external-controller 端口/secret 由 CoreController 生成并注入扩展（见 core 层），
/// 不在此 YAML 中。
class RuntimeConfig {
  /// 生成运行时 mihomo YAML：DNS fake-ip + 订阅 proxy-providers + 最小规则。
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
  subscription:
    type: http
    url: "$subscriptionUrl"
    interval: 86400
    path: ./providers/subscription.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
proxy-groups:
  - name: PROXY
    type: select
    use: [subscription]
rules:
  - MATCH,PROXY
''';
  }
}
