// geo 规则转 mrs rule-set 的纯函数测试（p1-geo-mrs-conversion 组 1，TDD）。
// 场景来源：openspec/changes/p1-geo-mrs-conversion/specs/geo-rule-conversion/spec.md
package mihomocore

import (
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
)

const (
	wantGeositeGoogleURL = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/google.mrs"
	wantGeoipCNURL       = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geoip/cn.mrs"
)

// assertProvider 断言注入的 provider map 含期望键值。
func assertProvider(t *testing.T, rp map[string]any, want map[string]any) {
	t.Helper()
	for k, v := range want {
		got, ok := rp[k]
		if !ok {
			t.Errorf("provider 缺字段 %q", k)
			continue
		}
		if got != v {
			t.Errorf("provider[%q]=%v(%T)，期望 %v(%T)", k, got, got, v, v)
		}
	}
}

// 场景：GEOSITE 规则转换
func TestRewriteGeoRules_GEOSITE(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{"GEOSITE,google,PROXY"}}
	rewriteGeoRules(cfg)

	if got := cfg.Rule[0]; got != "RULE-SET,geosite-google,PROXY" {
		t.Fatalf("规则改写错误: %q", got)
	}
	rp, ok := cfg.RuleProvider["geosite-google"]
	if !ok {
		t.Fatal("未注入 geosite-google provider")
	}
	assertProvider(t, rp, map[string]any{
		"type":           "http",
		"behavior":       "domain",
		"format":         "mrs",
		"url":            wantGeositeGoogleURL,
		"path":           "./ruleset/geosite-google.mrs",
		"path-in-bundle": "geosite/google.mrs",
		"interval":       86400,
	})
}

// 场景：GEOIP 规则转换（含 no-resolve 参数保留）
func TestRewriteGeoRules_GEOIP(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{"GEOIP,cn,DIRECT,no-resolve"}}
	rewriteGeoRules(cfg)

	if got := cfg.Rule[0]; got != "RULE-SET,geoip-cn,DIRECT,no-resolve" {
		t.Fatalf("规则改写错误（应保留 no-resolve）: %q", got)
	}
	rp, ok := cfg.RuleProvider["geoip-cn"]
	if !ok {
		t.Fatal("未注入 geoip-cn provider")
	}
	assertProvider(t, rp, map[string]any{
		"type":           "http",
		"behavior":       "ipcidr",
		"format":         "mrs",
		"url":            wantGeoipCNURL,
		"path":           "./ruleset/geoip-cn.mrs",
		"path-in-bundle": "geoip/cn.mrs",
		"interval":       86400,
	})
}

// 场景：首匹配顺序不变（原位替换）
func TestRewriteGeoRules_PreserveOrder(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{
		"DOMAIN,example.com,DIRECT",
		"GEOSITE,google,PROXY",
		"MATCH,DIRECT",
	}}
	rewriteGeoRules(cfg)

	want := []string{
		"DOMAIN,example.com,DIRECT",
		"RULE-SET,geosite-google,PROXY",
		"MATCH,DIRECT",
	}
	for i, w := range want {
		if cfg.Rule[i] != w {
			t.Errorf("第 %d 条规则=%q，期望 %q", i, cfg.Rule[i], w)
		}
	}
}

// 场景：同类别去重（多规则共享一个 provider）
func TestRewriteGeoRules_Dedup(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{
		"GEOSITE,google,PROXY",
		"GEOSITE,google,DIRECT",
	}}
	rewriteGeoRules(cfg)

	if cfg.Rule[0] != "RULE-SET,geosite-google,PROXY" || cfg.Rule[1] != "RULE-SET,geosite-google,DIRECT" {
		t.Fatalf("两条规则均应转换: %v", cfg.Rule)
	}
	if len(cfg.RuleProvider) != 1 {
		t.Errorf("应去重为 1 个 provider，实际 %d 个: %v", len(cfg.RuleProvider), cfg.RuleProvider)
	}
}

// 场景：合法特殊字符（! @）原样保留于 name/url/path（不替换，避免碰撞）
func TestRewriteGeoRules_SpecialCharsPreserved(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{"GEOSITE,category-social-media-!cn,PROXY"}}
	rewriteGeoRules(cfg)

	if got := cfg.Rule[0]; got != "RULE-SET,geosite-category-social-media-!cn,PROXY" {
		t.Fatalf("特殊字符应保留: %q", got)
	}
	rp := cfg.RuleProvider["geosite-category-social-media-!cn"]
	if rp == nil {
		t.Fatal("未注入 provider")
	}
	assertProvider(t, rp, map[string]any{
		"path":           "./ruleset/geosite-category-social-media-!cn.mrs",
		"path-in-bundle": "geosite/category-social-media-!cn.mrs",
		"url":            "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/category-social-media-!cn.mrs",
	})
}

// 场景：旧 sanitize 会碰撞的两类别（@/! 都→_）现保留原字符 → 不同 name、各自 url 正确（防分流错配）
func TestRewriteGeoRules_NoCollision(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{
		"GEOSITE,test@cn,PROXY",
		"GEOSITE,test!cn,DIRECT",
	}}
	rewriteGeoRules(cfg)

	if cfg.Rule[0] != "RULE-SET,geosite-test@cn,PROXY" || cfg.Rule[1] != "RULE-SET,geosite-test!cn,DIRECT" {
		t.Fatalf("两类别应映射到不同 provider: %v", cfg.Rule)
	}
	if len(cfg.RuleProvider) != 2 {
		t.Fatalf("应注入 2 个不同 provider，实际 %d", len(cfg.RuleProvider))
	}
	const base = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/"
	if cfg.RuleProvider["geosite-test@cn"]["url"] != base+"test@cn.mrs" {
		t.Errorf("test@cn url 错配: %v", cfg.RuleProvider["geosite-test@cn"]["url"])
	}
	if cfg.RuleProvider["geosite-test!cn"]["url"] != base+"test!cn.mrs" {
		t.Errorf("test!cn url 错配: %v", cfg.RuleProvider["geosite-test!cn"]["url"])
	}
}

// 场景：畸形类别（空 / 含斜杠 / 含内部空格）跳过转换，保留原规则、不注入 provider
func TestRewriteGeoRules_InvalidCategorySkipped(t *testing.T) {
	for _, rule := range []string{"GEOSITE,,PROXY", "GEOSITE,a/b,PROXY", "GEOSITE,a b,PROXY"} {
		cfg := &config.RawConfig{Rule: []string{rule}}
		rewriteGeoRules(cfg)
		if cfg.Rule[0] != rule {
			t.Errorf("畸形类别应保留原规则: %q → %q", rule, cfg.Rule[0])
		}
		if len(cfg.RuleProvider) != 0 {
			t.Errorf("畸形类别不应注入 provider: %q", rule)
		}
	}
}

// 场景：类别名首尾空格被 trim 后正常转换
func TestRewriteGeoRules_TrimsCategory(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{"GEOSITE, google ,PROXY"}}
	rewriteGeoRules(cfg)
	if cfg.Rule[0] != "RULE-SET,geosite-google,PROXY" {
		t.Fatalf("类别首尾空格应 trim: %q", cfg.Rule[0])
	}
	if _, ok := cfg.RuleProvider["geosite-google"]; !ok {
		t.Error("未注入 geosite-google")
	}
}

// 场景：ASN 类跳过（保留原样，不注入 provider）
func TestRewriteGeoRules_SkipASN(t *testing.T) {
	cfg := &config.RawConfig{Rule: []string{
		"IP-ASN,13335,DIRECT",
		"GEOSITE,google,PROXY",
	}}
	rewriteGeoRules(cfg)

	if cfg.Rule[0] != "IP-ASN,13335,DIRECT" {
		t.Errorf("IP-ASN 不应被转换: %q", cfg.Rule[0])
	}
	if _, ok := cfg.RuleProvider["geosite-google"]; !ok {
		t.Error("GEOSITE 仍应转换")
	}
	if len(cfg.RuleProvider) != 1 {
		t.Errorf("仅 GEOSITE 注入 1 个 provider，实际 %d", len(cfg.RuleProvider))
	}
}

// buildRawConfig 接入：开关开启时 geo 规则被转换
func TestBuildRawConfig_GeoConvertOn(t *testing.T) {
	yaml := "rules:\n  - GEOSITE,google,PROXY\n"
	cfg, err := buildRawConfig(yaml, coreOverrides{ConvertGeoRules: true})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	for _, r := range cfg.Rule {
		if strings.HasPrefix(r, "GEOSITE,") {
			t.Errorf("开关开启时 GEOSITE 应被转换，残留: %q", r)
		}
	}
	if _, ok := cfg.RuleProvider["geosite-google"]; !ok {
		t.Error("开关开启时应注入 geosite-google provider")
	}
}

// buildRawConfig 接入：开关关闭时 geo 规则保持原样（回滚开关）
func TestBuildRawConfig_GeoConvertOff(t *testing.T) {
	yaml := "rules:\n  - GEOSITE,google,PROXY\n"
	cfg, err := buildRawConfig(yaml, coreOverrides{ConvertGeoRules: false})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	found := false
	for _, r := range cfg.Rule {
		if r == "GEOSITE,google,PROXY" {
			found = true
		}
	}
	if !found {
		t.Errorf("开关关闭时 GEOSITE 应保留，实际规则: %v", cfg.Rule)
	}
	if _, ok := cfg.RuleProvider["geosite-google"]; ok {
		t.Error("开关关闭时不应注入 provider")
	}
}

// 场景：非 geo 规则原样不动，不注入 provider
func TestRewriteGeoRules_NonGeoUntouched(t *testing.T) {
	in := []string{"DOMAIN-SUFFIX,example.com,DIRECT", "MATCH,DIRECT"}
	cfg := &config.RawConfig{Rule: append([]string{}, in...)}
	rewriteGeoRules(cfg)

	for i, w := range in {
		if cfg.Rule[i] != w {
			t.Errorf("非 geo 规则被改: %q → %q", w, cfg.Rule[i])
		}
	}
	if len(cfg.RuleProvider) != 0 {
		t.Errorf("不应注入任何 provider，实际 %d", len(cfg.RuleProvider))
	}
}
