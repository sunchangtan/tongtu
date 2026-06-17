// TUN 模式 fake-ip DNS 覆写与 proxy-provider 缓存 path 注入测试
// 对应 openspec/changes/p1-subscription-as-config 的 core-bridge spec
// 「TUN 模式 DNS 覆写注入」「proxy-provider 本地缓存 path 注入」需求。
package mihomocore

import (
	"strings"
	"testing"

	mihomoConst "github.com/metacubex/mihomo/constant"
)

// 场景：TUN 模式 + 订阅自带 DNS → 保留上游、强制 fake-ip、补 filter、dns-hijack、持久化
func TestBuildRawConfig_TunKeepsUpstreamAndForcesFakeIP(t *testing.T) {
	yaml := "mixed-port: 7890\n" +
		"dns:\n" +
		"  enable: true\n" +
		"  nameserver:\n" +
		"    - https://doh.pub/dns-query\n" +
		"  proxy-server-nameserver:\n" +
		"    - https://dns.alidns.com/dns-query\n"
	rawCfg, err := buildRawConfig(yaml, coreOverrides{TunFD: 100})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	if rawCfg.DNS.EnhancedMode != mihomoConst.DNSFakeIP {
		t.Errorf("enhanced-mode 应为 fake-ip，实际 %v", rawCfg.DNS.EnhancedMode)
	}
	if !rawCfg.DNS.Enable {
		t.Error("dns.enable 应为 true")
	}
	if rawCfg.DNS.FakeIPRange == "" {
		t.Error("fake-ip-range 应已设")
	}
	if len(rawCfg.DNS.FakeIPFilter) == 0 {
		t.Error("fake-ip-filter 应非空")
	}
	if !strings.Contains(strings.Join(rawCfg.DNS.NameServer, ","), "doh.pub") {
		t.Errorf("应保留订阅 nameserver 上游，实际 %v", rawCfg.DNS.NameServer)
	}
	if len(rawCfg.DNS.ProxyServerNameserver) == 0 {
		t.Error("应保留订阅 proxy-server-nameserver 上游")
	}
	if len(rawCfg.Tun.DNSHijack) == 0 {
		t.Error("tun.dns-hijack 应已设")
	}
	if !rawCfg.Profile.StoreFakeIP {
		t.Error("profile.store-fake-ip 应启用")
	}
}

// 场景：TUN 模式 + 订阅无 DNS → 用默认 fake-ip DNS（含默认 nameserver、filter）
func TestBuildRawConfig_TunDefaultDNSWhenAbsent(t *testing.T) {
	rawCfg, err := buildRawConfig("mixed-port: 7890\n", coreOverrides{TunFD: 100})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	if rawCfg.DNS.EnhancedMode != mihomoConst.DNSFakeIP {
		t.Error("应为 fake-ip")
	}
	if len(rawCfg.DNS.NameServer) == 0 {
		t.Error("应有 nameserver（默认 DoH）")
	}
	if len(rawCfg.DNS.FakeIPFilter) == 0 {
		t.Error("应注入默认 fake-ip-filter")
	}
}

// 场景：非 TUN 模式 → 不启用 tun，也不强制 fake-ip 持久化
func TestBuildRawConfig_NonTunNoInject(t *testing.T) {
	rawCfg, err := buildRawConfig("mixed-port: 7890\n", coreOverrides{TunFD: 0})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	if rawCfg.Tun.Enable {
		t.Error("非 TUN 不应启用 tun")
	}
	if rawCfg.Profile.StoreFakeIP {
		t.Error("非 TUN 不应启用 store-fake-ip")
	}
}

// 场景：http proxy-provider 注入本地缓存 path（file 类型不注入）
func TestBuildRawConfig_InjectProviderCachePath(t *testing.T) {
	yaml := "mixed-port: 7890\n" +
		"proxy-providers:\n" +
		"  sub1:\n" +
		"    type: http\n" +
		"    url: \"http://example.com/sub1\"\n"
	rawCfg, err := buildRawConfig(yaml, coreOverrides{TunFD: 100})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	prov := rawCfg.ProxyProvider["sub1"]
	if prov == nil {
		t.Fatal("无 sub1 provider")
	}
	path, _ := prov["path"].(string)
	if !strings.HasPrefix(path, "providers/") {
		t.Errorf("http provider 应注入 providers/ 下的 path，实际 %q", path)
	}
}
