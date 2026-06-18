// geo 规则 → mrs rule-set 自动转换（p1-geo-mrs-conversion）。
// 把订阅 rules 段的 GEOSITE/GEOIP 规则改写为引用 mrs rule-provider 的 RULE-SET，
// 避免 mihomo 在 parseRules 阶段 eager 全量加载 geosite.dat（实测 +16.5MB Go 堆），
// 改为按需紧凑加载 mrs，适配 iOS NE 50MB 内存硬限。设计见
// openspec/changes/p1-geo-mrs-conversion/design.md。
package mihomocore

import (
	"strings"

	"github.com/metacubex/mihomo/config"
)

// mrsBaseURL 是 geo mrs 数据源基址（metacubex meta-rules-dat，testingcf jsdelivr CDN，已验证可达）。
const mrsBaseURL = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo"

// geoRuleUpdateInterval 是注入的 rule-provider 自动更新周期（秒，24h）。
const geoRuleUpdateInterval = 86400

// rewriteGeoRules 把 rawCfg.Rule 中的 GEOSITE/GEOIP 规则原位改写为引用 mrs rule-provider
// 的 RULE-SET 规则（保持首匹配顺序），并向 rawCfg.RuleProvider 注入对应 provider（同类别去重）。
// GEOSITE→behavior:domain，GEOIP→behavior:ipcidr；ASN/其他规则原样不动。
func rewriteGeoRules(rawCfg *config.RawConfig) {
	for i, rule := range rawCfg.Rule {
		parts := strings.Split(rule, ",")
		if len(parts) < 3 {
			continue // 非完整规则（至少 类型,载荷,目标）
		}
		var subdir, behavior string
		switch {
		case strings.EqualFold(parts[0], "GEOSITE"):
			subdir, behavior = "geosite", "domain"
		case strings.EqualFold(parts[0], "GEOIP"):
			subdir, behavior = "geoip", "ipcidr"
		default:
			continue // 非 GEOSITE/GEOIP（含 IP-ASN/GEODATA 等），不转换
		}
		category := strings.TrimSpace(parts[1])
		if !isValidGeoCategory(category) {
			continue // 畸形类别（空/含非法字符）：跳过转换、保留原规则交内核处理，避免错配与注入
		}
		rest := parts[2:] // 目标 + 参数（no-resolve 等）
		name := subdir + "-" + category

		// 原位改写为 RULE-SET（保持顺序）
		rawCfg.Rule[i] = "RULE-SET," + name + "," + strings.Join(rest, ",")

		// 注入 provider（同类别去重：已存在则只改写规则、不重复注入）
		if rawCfg.RuleProvider == nil {
			rawCfg.RuleProvider = map[string]map[string]any{}
		}
		if _, exists := rawCfg.RuleProvider[name]; exists {
			continue
		}
		rawCfg.RuleProvider[name] = map[string]any{
			"type":           "http",
			"behavior":       behavior,
			"format":         "mrs",
			"url":            mrsBaseURL + "/" + subdir + "/" + category + ".mrs",
			"path":           "./ruleset/" + name + ".mrs",
			"path-in-bundle": subdir + "/" + category + ".mrs",
			"interval":       geoRuleUpdateInterval,
		}
	}
}

// isValidGeoCategory 校验 geo 类别名是否安全可直接用于 provider name / 本地 path / url / path-in-bundle：
// 非空且仅含 meta-rules-dat 合法字符 [a-zA-Z0-9-@!._]。逗号/斜杠/空格等畸形输入返回 false（跳过转换）——
// 既防 URL/路径注入与 bundle 路径穿越，也避免「替换为 _」导致不同类别（如 a@b 与 a!b）碰撞、provider 张冠李戴。
func isValidGeoCategory(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9',
			r == '-', r == '@', r == '!', r == '.', r == '_':
		default:
			return false
		}
	}
	return true
}
