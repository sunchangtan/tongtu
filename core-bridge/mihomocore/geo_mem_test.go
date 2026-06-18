// geo 转换内存验证（p1-geo-mrs-conversion 组 2.1，自包含 CI 可跑）：
// 合成含多条 GEOSITE/GEOIP 的最小配置，经 ConvertGeoRules 转换后，rules 段不再有 geo 规则，
// 内核 ParseRawConfig 的 parseRules 不会 eager 加载整库 geosite.dat，Go 堆增量应很小。
// （未转换实测会 +16.5MB，已在内核真实路径 + 真实订阅对照坐实，结论见 design.md §1。）
package mihomocore

import (
	"runtime"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
	mihomoConst "github.com/metacubex/mihomo/constant"
)

func TestGeoConvertKeepsParseHeapLow(t *testing.T) {
	mihomoConst.SetHomeDir(t.TempDir()) // 隔离 rule-provider path 解析，不污染用户环境

	cats := []string{
		"google", "youtube", "telegram", "netflix", "github",
		"twitter", "facebook", "apple", "microsoft", "spotify",
	}
	var b strings.Builder
	b.WriteString("proxies:\n  - {name: P, type: socks5, server: 127.0.0.1, port: 1080}\n")
	b.WriteString("proxy-groups:\n  - {name: PROXY, type: select, proxies: [P]}\n")
	b.WriteString("rules:\n")
	for _, c := range cats {
		b.WriteString("  - GEOSITE," + c + ",PROXY\n")
	}
	b.WriteString("  - GEOIP,cn,DIRECT\n  - MATCH,PROXY\n")

	cfg, err := buildRawConfig(b.String(), coreOverrides{ConvertGeoRules: true})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	for _, r := range cfg.Rule {
		if strings.HasPrefix(r, "GEOSITE,") || strings.HasPrefix(r, "GEOIP,") {
			t.Fatalf("转换后不应残留 geo 规则: %q", r)
		}
	}

	var h0 runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&h0)
	parsed, err := config.ParseRawConfig(cfg)
	if err != nil {
		t.Fatalf("ParseRawConfig: %v", err)
	}
	var h1 runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&h1)
	runtime.KeepAlive(parsed)

	deltaMB := float64(int64(h1.HeapAlloc)-int64(h0.HeapAlloc)) / 1024 / 1024 // int64 防 uint 下溢（堆可能反而减少）
	t.Logf("转换后 ParseRawConfig 堆增量=%.2fMB（未转换约 +16.5MB）", deltaMB)
	if deltaMB > 5 {
		t.Errorf("转换后堆增量 %.2fMB 过大，疑似仍加载 geo 数据库", deltaMB)
	}
}
