// proxy-provider 外网容灾测试：远程订阅源不可达 + 本地缓存存在 → 内核回退缓存节点。
// 对应 openspec/changes/p1-subscription-as-config core-bridge spec
// 「远程不可达时回退本地缓存」场景，坐实 buildRawConfig 注入 path 的容灾价值。
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

	const url = "http://127.0.0.1:1/unreachable" // 必不可达
	cacheRel := "providers/" + hashProviderURL(url) + ".yaml"
	cacheAbs := filepath.Join(home, cacheRel)
	if err := os.MkdirAll(filepath.Dir(cacheAbs), 0o755); err != nil {
		t.Fatal(err)
	}
	// 预置本地缓存：含一个可解析节点（模拟「曾在内网成功拉取过一次」）
	cache := "proxies:\n  - {name: cached-node, type: socks5, server: 127.0.0.1, port: 1080}\n"
	if err := os.WriteFile(cacheAbs, []byte(cache), 0o644); err != nil {
		t.Fatal(err)
	}

	yaml := "mixed-port: 7890\n" +
		"proxy-providers:\n" +
		"  sub1:\n" +
		"    type: http\n" +
		"    url: \"" + url + "\"\n" +
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
	if got, _ := rawCfg.ProxyProvider["sub1"]["path"].(string); got != cacheRel {
		t.Fatalf("注入 path=%q，期望 %q", got, cacheRel)
	}
	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		t.Fatalf("ParseRawConfig: %v", err)
	}
	prov := cfg.Providers["sub1"]
	if prov == nil {
		t.Fatal("无 sub1 provider")
	}
	_ = prov.Initial() // 远程不可达，但本地缓存存在 → 应回退缓存
	if n := len(prov.Proxies()); n == 0 {
		t.Fatal("远程不可达时应回退本地缓存节点，实际 0（容灾失效）")
	}
}
