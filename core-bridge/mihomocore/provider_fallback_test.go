// proxy-provider 外网容灾测试：远程订阅源不可达 + 本地缓存存在 → 内核回退缓存节点。
// 对应 core-bridge spec「远程不可达时回退本地缓存」；同时验证 buildRawConfig 不再覆盖
// 订阅显式指定的 provider path（review 修复 #2：缓存改由内核默认 md5(url) 自管，尊重订阅 path）。
package mihomocore

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/config"
	mihomoConst "github.com/metacubex/mihomo/constant"
)

func TestProviderFallbackToCacheWhenRemoteUnreachable(t *testing.T) {
	home := t.TempDir()
	mihomoConst.SetHomeDir(home)

	// 订阅为 provider 显式指定 path（应被保留，不被覆盖），并预置本地缓存
	const cacheRel = "providers/cached_sub.yaml"
	cacheAbs := filepath.Join(home, cacheRel)
	if err := os.MkdirAll(filepath.Dir(cacheAbs), 0o755); err != nil {
		t.Fatal(err)
	}
	cache := "proxies:\n  - {name: cached-node, type: socks5, server: 127.0.0.1, port: 1080}\n"
	if err := os.WriteFile(cacheAbs, []byte(cache), 0o644); err != nil {
		t.Fatal(err)
	}

	yaml := "mixed-port: 7890\n" +
		"proxy-providers:\n" +
		"  sub1:\n" +
		"    type: http\n" +
		"    url: \"http://127.0.0.1:1/unreachable\"\n" + // 必不可达
		"    path: \"" + cacheRel + "\"\n" +
		"    interval: 3600\n" +
		"proxy-groups:\n" +
		"  - name: PROXY\n" +
		"    type: select\n" +
		"    use: [sub1]\n" +
		"rules:\n" +
		"  - MATCH,PROXY\n"

	rawCfg, err := buildRawConfig(yaml, coreOverrides{})
	if err != nil {
		t.Fatalf("buildRawConfig: %v", err)
	}
	// 修复 #2：不再覆盖订阅显式 path
	if got, _ := rawCfg.ProxyProvider["sub1"]["path"].(string); got != cacheRel {
		t.Fatalf("应保留订阅显式 path=%q，实际 %q（不应被覆盖）", cacheRel, got)
	}
	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		t.Fatalf("ParseRawConfig: %v", err)
	}
	prov := cfg.Providers["sub1"]
	if prov == nil {
		t.Fatal("无 sub1 provider")
	}
	_ = prov.Initial() // 远程不可达，但本地缓存存在 → 回退（fetcher.Initial 本地→远程）
	if n := len(prov.Proxies()); n == 0 {
		t.Fatal("远程不可达时应回退本地缓存节点，实际 0（外网容灾失效）")
	}
}
