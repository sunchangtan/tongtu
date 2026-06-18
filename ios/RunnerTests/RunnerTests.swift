import NetworkExtension
import XCTest

@testable import Runner

/// `OnDemandRuleBuilder` 纯函数单测：验证语义配置 → 有序 `NEOnDemandRule` 的映射。
///
/// 逻辑亦经独立 `swiftc` + `simctl spawn`（iOS Simulator）运行验证；此处为入库 XCTest，
/// 随 `xcodebuild test` 在完整构建环境复跑。
final class OnDemandRuleBuilderTests: XCTestCase {
  func testTrustedDisconnectOnTopWithAllScope() throws {
    let cfg = OnDemandConfig(
      enabled: true,
      scope: .all,
      trustedSSIDs: ["Home", "Office"]
    )
    let rules = OnDemandRuleBuilder.build(cfg)
    let first = try XCTUnwrap(rules.first as? NEOnDemandRuleDisconnect)
    XCTAssertEqual(first.ssidMatch, ["Home", "Office"])
    XCTAssertGreaterThanOrEqual(rules.count, 2)
    let second = try XCTUnwrap(rules[1] as? NEOnDemandRuleConnect)
    XCTAssertEqual(second.interfaceTypeMatch, .any)
  }

  func testWifiOnly() throws {
    let cfg = OnDemandConfig(enabled: true, scope: .wifiOnly, trustedSSIDs: [])
    let rules = OnDemandRuleBuilder.build(cfg)
    let first = try XCTUnwrap(rules.first as? NEOnDemandRuleConnect)
    XCTAssertEqual(first.interfaceTypeMatch, .wiFi)
    let last = try XCTUnwrap(rules.last as? NEOnDemandRuleDisconnect)
    XCTAssertEqual(last.interfaceTypeMatch, .any)
  }

  func testCellularOnly() throws {
    let cfg = OnDemandConfig(
      enabled: true,
      scope: .cellularOnly,
      trustedSSIDs: []
    )
    let rules = OnDemandRuleBuilder.build(cfg)
    let first = try XCTUnwrap(rules.first as? NEOnDemandRuleConnect)
    XCTAssertEqual(first.interfaceTypeMatch, .cellular)
    let last = try XCTUnwrap(rules.last as? NEOnDemandRuleDisconnect)
    XCTAssertEqual(last.interfaceTypeMatch, .any)
  }

  func testEmptyTrustedProducesNoSSIDRule() {
    let cfg = OnDemandConfig(enabled: true, scope: .all, trustedSSIDs: [])
    let rules = OnDemandRuleBuilder.build(cfg)
    XCTAssertFalse(rules.contains { ($0.ssidMatch?.isEmpty == false) })
  }

  func testTrustedPrecedesScopeRules() throws {
    let cfg = OnDemandConfig(
      enabled: true,
      scope: .wifiOnly,
      trustedSSIDs: ["Cafe"]
    )
    let rules = OnDemandRuleBuilder.build(cfg)
    XCTAssertEqual(rules.count, 3)
    let first = try XCTUnwrap(rules.first as? NEOnDemandRuleDisconnect)
    XCTAssertEqual(first.ssidMatch, ["Cafe"])
    let second = try XCTUnwrap(rules[1] as? NEOnDemandRuleConnect)
    XCTAssertEqual(second.interfaceTypeMatch, .wiFi)
  }
}
