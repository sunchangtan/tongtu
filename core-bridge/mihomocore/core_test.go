// core-bridge 接口契约测试（任务 2.1）
// 每个测试对应 openspec/changes/p0-core-bridge/specs/core-bridge/spec.md 的一个场景。
package mihomocore

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"runtime/debug"
	"strings"
	"testing"
	"time"
)

// validConfig 最小合法配置（不开 TUN，适合单测环境）
const validConfig = `
log-level: silent
mode: rule
`

// freePort 申请一个空闲回环端口
func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("申请空闲端口失败: %v", err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// overrides 构造覆写 JSON
func overrides(t *testing.T, port int, secret string) string {
	t.Helper()
	b, err := json.Marshal(map[string]any{
		"external-controller": fmt.Sprintf("127.0.0.1:%d", port),
		"secret":              secret,
		"home-dir":            t.TempDir(), // 隔离内核工作目录，避免污染用户环境
	})
	if err != nil {
		t.Fatalf("构造覆写 JSON 失败: %v", err)
	}
	return string(b)
}

// mustStart 启动内核并注册清理
func mustStart(t *testing.T, configYAML, overridesJSON string) {
	t.Helper()
	if err := Start(configYAML, overridesJSON); err != nil {
		t.Fatalf("Start 失败: %v", err)
	}
	t.Cleanup(func() { _ = Stop() })
}

// apiGet 带鉴权请求外部控制器
func apiGet(t *testing.T, port int, secret, path string) (*http.Response, error) {
	t.Helper()
	req, err := http.NewRequest("GET", fmt.Sprintf("http://127.0.0.1:%d%s", port, path), nil)
	if err != nil {
		t.Fatalf("构造请求失败: %v", err)
	}
	if secret != "" {
		req.Header.Set("Authorization", "Bearer "+secret)
	}
	client := &http.Client{Timeout: 3 * time.Second}
	return client.Do(req)
}

// 场景：合法配置启动 —— 内核进入运行状态，external-controller 在配置指定的回环地址可达
func TestStartWithValidConfig(t *testing.T) {
	port := freePort(t)
	mustStart(t, validConfig, overrides(t, port, "test-secret"))

	if got := State(); got != "running" {
		t.Fatalf("状态应为 running，实际为 %q", got)
	}
	resp, err := apiGet(t, port, "test-secret", "/version")
	if err != nil {
		t.Fatalf("external-controller 不可达: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("/version 应返回 200，实际为 %d", resp.StatusCode)
	}
}

// 场景：非法配置启动 —— 返回含定位信息的错误，内核不残留任何运行资源
func TestStartWithInvalidYAML(t *testing.T) {
	err := Start("proxies: [未闭合的列表", "")
	if err == nil {
		_ = Stop()
		t.Fatal("非法 YAML 应返回错误")
	}
	if !strings.Contains(err.Error(), "line") {
		t.Errorf("错误信息应含行号定位（line），实际为: %v", err)
	}
	if got := State(); got != "stopped" {
		t.Fatalf("启动失败后状态应为 stopped，实际为 %q", got)
	}
}

// 场景：停止与资源回收 —— 监听端口关闭，状态回到 stopped，且可再次启动
func TestStopReleasesResources(t *testing.T) {
	port := freePort(t)
	mustStart(t, validConfig, overrides(t, port, "s1"))

	if err := Stop(); err != nil {
		t.Fatalf("Stop 失败: %v", err)
	}
	if got := State(); got != "stopped" {
		t.Fatalf("停止后状态应为 stopped，实际为 %q", got)
	}
	if _, err := apiGet(t, port, "s1", "/version"); err == nil {
		t.Fatal("停止后 external-controller 端口应已关闭")
	}
	// 同端口可再次启动（验证端口已真正释放）
	mustStart(t, validConfig, overrides(t, port, "s2"))
	if got := State(); got != "running" {
		t.Fatalf("重新启动后状态应为 running，实际为 %q", got)
	}
}

// 场景：热重载配置 —— 新配置生效且现有进程不退出
func TestReloadAppliesNewConfig(t *testing.T) {
	port := freePort(t)
	mustStart(t, validConfig, overrides(t, port, "reload-secret"))

	newConfig := strings.Replace(validConfig, "mode: rule", "mode: global", 1)
	if err := Reload(newConfig); err != nil {
		t.Fatalf("Reload 失败: %v", err)
	}
	if got := State(); got != "running" {
		t.Fatalf("重载后状态应保持 running，实际为 %q", got)
	}
	resp, err := apiGet(t, port, "reload-secret", "/configs")
	if err != nil {
		t.Fatalf("重载后 external-controller 不可达: %v", err)
	}
	defer resp.Body.Close()
	var cfg struct {
		Mode string `json:"mode"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&cfg); err != nil {
		t.Fatalf("解析 /configs 失败: %v", err)
	}
	if !strings.EqualFold(cfg.Mode, "global") {
		t.Fatalf("重载后 mode 应为 global，实际为 %q", cfg.Mode)
	}
}

// 场景：注入随机端口与 secret —— 无凭据请求被拒绝（HTTP 401），有凭据可达
func TestControllerSecretEnforced(t *testing.T) {
	port := freePort(t)
	mustStart(t, validConfig, overrides(t, port, "strong-secret"))

	resp, err := apiGet(t, port, "", "/configs")
	if err != nil {
		t.Fatalf("请求失败: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("无凭据请求应返回 401，实际为 %d", resp.StatusCode)
	}

	resp2, err := apiGet(t, port, "strong-secret", "/configs")
	if err != nil {
		t.Fatalf("带凭据请求失败: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("带凭据请求应返回 200，实际为 %d", resp2.StatusCode)
	}
}

// 场景：默认内存防护生效 —— GOMEMLIMIT 为默认值（30MiB），内存查询接口返回有效数据
func TestDefaultMemoryProtection(t *testing.T) {
	port := freePort(t)
	mustStart(t, validConfig, overrides(t, port, "mem-secret"))

	const defaultLimit = int64(30) << 20 // 30 MiB
	if got := debug.SetMemoryLimit(-1); got != defaultLimit {
		t.Errorf("GOMEMLIMIT 默认值应为 %d（30MiB），实际为 %d", defaultLimit, got)
	}

	var stats struct {
		HeapAlloc   uint64 `json:"heapAlloc"`
		HeapSys     uint64 `json:"heapSys"`
		TotalSys    uint64 `json:"totalSys"`
		MemoryLimit int64  `json:"memoryLimit"`
	}
	raw := MemoryStats()
	if err := json.Unmarshal([]byte(raw), &stats); err != nil {
		t.Fatalf("MemoryStats 应返回合法 JSON，实际为 %q: %v", raw, err)
	}
	if stats.HeapAlloc == 0 || stats.TotalSys == 0 {
		t.Errorf("内存占用数据应非零: %+v", stats)
	}
	if stats.MemoryLimit != defaultLimit {
		t.Errorf("memoryLimit 应为 %d，实际为 %d", defaultLimit, stats.MemoryLimit)
	}
}
