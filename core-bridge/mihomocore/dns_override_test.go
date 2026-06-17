// TUN 模式 fake-ip DNS 覆写测试
// 对应 openspec/changes/p1-subscription-as-config 的 core-bridge spec「TUN 模式 DNS 覆写注入」。
package mihomocore

import (
	"strings"
	"testing"

	mihomoConst "github.com/metacubex/mihomo/constant"
)

func containsStr(ss []string, target string) bool {
	for _, s := range ss {
		if s == target {
			return true
		}
	}
	return false
}

// 场景：TUN + 订阅自带 DNS → 保留上游 nameserver、强制 fake-ip、filter 并集（必需项 + 订阅自带项都在）
func TestBuildRawConfig_TunKeepsUpstreamAndForcesFakeIP(t *testing.T) {
	yaml := "mixed-port: 7890\n" +
		"dns:\n" +
		"  enable: true\n" +
		"  nameserver:\n" +
		"    - https://doh.pub/dns-query\n" +
		"  fake-ip-filter:\n" +
		"    - \"+.example.test\"\n"
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
	if rawCfg.DNS.FakeIPRange != fakeIPRange {
		t.Errorf("fake-ip-range=%q 应为 %q", rawCfg.DNS.FakeIPRange, fakeIPRange)
	}
	if !strings.Contains(strings.Join(rawCfg.DNS.NameServer, ","), "doh.pub") {
		t.Errorf("应保留订阅 nameserver 上游，实际 %v", rawCfg.DNS.NameServer)
	}
	if !containsStr(rawCfg.DNS.FakeIPFilter, "*.push.apple.com") {
		t.Error("fake-ip-filter 应含必需项 *.push.apple.com（防 APNs 被 fake-ip 走代理）")
	}
	if !containsStr(rawCfg.DNS.FakeIPFilter, "+.example.test") {
		t.Error("fake-ip-filter 应保留订阅自带项 +.example.test")
	}
	if len(rawCfg.Tun.DNSHijack) == 0 {
		t.Error("tun.dns-hijack 应已设")
	}
	if !rawCfg.Profile.StoreFakeIP {
		t.Error("profile.store-fake-ip 应启用")
	}
}

// 回归（修复 #1 守卫死代码）：订阅无 dns 段时，UnmarshalRawConfig 以 DefaultRawConfig 为基底，
// DNS.FakeIPFilter 已预置上游默认（非空）——必需项仍须经并集补入，旧的 len==0 守卫会漏掉。
func TestBuildRawConfig_TunForcesFilterEvenWhenUpstreamDefaultsPresent(t *testing.T) {
	rawCfg, err := buildRawConfig("mixed-port: 7890\n", coreOverrides{TunFD: 100})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	if rawCfg.DNS.EnhancedMode != mihomoConst.DNSFakeIP {
		t.Error("应为 fake-ip")
	}
	if !containsStr(rawCfg.DNS.FakeIPFilter, "*.push.apple.com") {
		t.Error("上游默认 filter 非空时，仍须并集补入 *.push.apple.com（否则 APNs 推送断裂）")
	}
	if len(rawCfg.DNS.NameServer) == 0 {
		t.Error("应有 nameserver（上游默认 DoH 基底）")
	}
}

// 场景：非 TUN → 不启用 tun、不强制 fake-ip 持久化
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

// unionStrings 去重保序
func TestUnionStrings(t *testing.T) {
	got := unionStrings([]string{"a", "b"}, []string{"b", "c"})
	if strings.Join(got, ",") != "a,b,c" {
		t.Errorf("unionStrings=%v 期望 [a b c]", got)
	}
}
