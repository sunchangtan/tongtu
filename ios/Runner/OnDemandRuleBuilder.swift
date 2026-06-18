import NetworkExtension

/// 按需连接触发范围（与 Dart `OnDemandScope` 对齐，rawValue 即枚举名）。
enum OnDemandScope: String {
  case all
  case wifiOnly
  case cellularOnly
}

/// 按需连接语义配置（由 MethodChannel 参数解析而来）。
struct OnDemandConfig {
  let enabled: Bool
  let scope: OnDemandScope
  let trustedSSIDs: [String]
}

/// 将语义配置翻译为有序 `NEOnDemandRule` 数组。
///
/// 数组按「首匹配生效」语义评估：信任 SSID 优先断开（置顶），随后按触发范围放行
/// 目标接口，其余接口由末条 `Disconnect(.any)` 兜底断开。
enum OnDemandRuleBuilder {
  static func build(_ config: OnDemandConfig) -> [NEOnDemandRule] {
    var rules: [NEOnDemandRule] = []

    // 信任 WiFi 优先断开（置顶，确保可信网络直连）。
    if !config.trustedSSIDs.isEmpty {
      let trusted = NEOnDemandRuleDisconnect()
      trusted.ssidMatch = config.trustedSSIDs
      rules.append(trusted)
    }

    // 触发范围：放行目标接口，其余由兜底断开。
    switch config.scope {
    case .all:
      // 任意接口均连接，无「范围外」网络，无需兜底。
      rules.append(connect(.any))
    case .wifiOnly:
      rules.append(connect(.wiFi))
      rules.append(disconnect(.any))
    case .cellularOnly:
      rules.append(connect(.cellular))
      rules.append(disconnect(.any))
    }

    return rules
  }

  private static func connect(
    _ interface: NEOnDemandRuleInterfaceType
  ) -> NEOnDemandRuleConnect {
    let rule = NEOnDemandRuleConnect()
    rule.interfaceTypeMatch = interface
    return rule
  }

  private static func disconnect(
    _ interface: NEOnDemandRuleInterfaceType
  ) -> NEOnDemandRuleDisconnect {
    let rule = NEOnDemandRuleDisconnect()
    rule.interfaceTypeMatch = interface
    return rule
  }
}

extension OnDemandConfig {
  /// 由 MethodChannel 参数字典解析按需连接配置；缺字段或类型不符均回退缺省。
  static func fromChannel(_ args: [String: Any]?) -> OnDemandConfig {
    let enabled = args?["enabled"] as? Bool ?? false
    let scope = OnDemandScope(rawValue: args?["scope"] as? String ?? "") ?? .all
    let trustedSSIDs = args?["trustedSSIDs"] as? [String] ?? []
    return OnDemandConfig(
      enabled: enabled,
      scope: scope,
      trustedSSIDs: trustedSSIDs
    )
  }
}
