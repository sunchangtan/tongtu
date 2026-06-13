// Package mihomocore 是通途（Tongtu）的 mihomo 内核桥接层。
// 设计决策见 openspec/changes/p0-core-bridge/design.md：
//   - D2：导出接口收敛为粗粒度函数，复杂结构一律 JSON 字符串，便于 gomobile 绑定与多宿主复用
//   - D4：内存防护参数（GOMEMLIMIT/GOGC/memconservative/FreeOSMemory 定时器）集中在本包 Start 流程内应用
package mihomocore

import (
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"runtime"
	"runtime/debug"
	"sync"
	"time"

	"github.com/metacubex/mihomo/config"
	mihomoConst "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
)

// 内存防护默认值（D4；30MiB 为 P0 压测扫描前的暂定档，任务 5.3 确定终值）
const (
	defaultMemLimitMiB = 30
	defaultGOGC        = 30
	freeOSInterval     = 30 * time.Second
)

// coreOverrides 调用方覆写项（JSON 协议，字段与 mihomo 配置键保持一致命名）
type coreOverrides struct {
	ExternalController string `json:"external-controller"` // 外部控制器监听地址（如 127.0.0.1:9090）
	Secret             string `json:"secret"`              // 外部控制器鉴权密钥
	HomeDir            string `json:"home-dir"`            // 内核工作目录（iOS 须指向 App Group 容器）
	GoMemLimitMiB      int64  `json:"gomemlimit-mib"`      // GOMEMLIMIT，单位 MiB，0 取默认值
	GoGC               int    `json:"gogc"`                // GOGC 百分比，0 取默认值
	TunFD              int    `json:"tun-fd"`              // 外部 TUN 文件描述符（iOS NE 从 packetFlow 取得），>0 时启用 TUN（D3）
}

var (
	mu            sync.Mutex
	state         = "stopped"
	lastOverrides coreOverrides // Reload 复用上次启动的覆写项
	freeOSStop    chan struct{}
)

// Start 以 YAML 配置启动内核。
// overridesJSON 为调用方覆写项，可传空字符串（全部取默认值）。
func Start(configYAML string, overridesJSON string) error {
	mu.Lock()
	defer mu.Unlock()
	if state == "running" {
		return errors.New("内核已在运行，请先 Stop 或使用 Reload")
	}

	ov, err := parseOverrides(overridesJSON)
	if err != nil {
		return err
	}
	// 内存防护必须先于内核初始化生效（D4）
	applyMemoryProtection(ov)
	if ov.HomeDir != "" {
		mihomoConst.SetHomeDir(ov.HomeDir)
	}

	state = "starting"
	if err := applyConfig(configYAML, ov); err != nil {
		state = "stopped"
		return err
	}
	// route 服务器异步启动（go start），等待控制器 HTTP 服务真正就绪后才算启动完成。
	// 用完整 HTTP 请求而非 TCP 拨测：保证上游 start() 已执行到 Serve（httpServer 赋值完成），
	// 规避上游 ReCreateServer 异步 goroutine 对全局 httpServer 的竞争窗口（详见 README 已知问题）。
	if ov.ExternalController != "" && !waitControllerReady(ov.ExternalController, ov.Secret, 3*time.Second) {
		state = "stopped"
		return errors.New("外部控制器启动超时: " + ov.ExternalController)
	}
	lastOverrides = ov
	startFreeOSMemoryTimer()
	state = "running"
	return nil
}

// Stop 停止内核并回收全部资源（外部控制器、监听端口、TUN 栈）。幂等：未运行时直接返回。
func Stop() error {
	mu.Lock()
	defer mu.Unlock()
	if state == "stopped" {
		return nil
	}
	stopFreeOSMemoryTimer()
	route.ReCreateServer(&route.Config{}) // 空地址 = 关闭外部控制器监听（异步）
	executor.Shutdown()                   // 清理入站监听与 TUN
	// 等待控制器端口真正释放，保证 Stop 返回后端口可立即复用
	if lastOverrides.ExternalController != "" {
		if !waitPortState(lastOverrides.ExternalController, false, 3*time.Second) {
			state = "stopped"
			return errors.New("外部控制器端口释放超时: " + lastOverrides.ExternalController)
		}
	}
	state = "stopped"
	return nil
}

// Reload 热重载配置：复用上次启动的覆写项，现有进程不退出。
func Reload(configYAML string) error {
	mu.Lock()
	defer mu.Unlock()
	if state != "running" {
		return errors.New("内核未运行，无法重载")
	}
	return applyConfig(configYAML, lastOverrides)
}

// State 返回内核状态：stopped / starting / running。
func State() string {
	mu.Lock()
	defer mu.Unlock()
	return state
}

// UpdateDefaultInterface 设置内核出站连接绑定的网络接口名（问题 9）。
// 宿主用 NWPathMonitor 监听网络变化、WiFi 优先取真实接口名后调用，
// 替代在 NE 沙盒里会误判蜂窝的 auto-detect-interface。
func UpdateDefaultInterface(name string) {
	dialer.DefaultInterface.Store(name)
}

// MemoryStats 返回 Go 运行时内存占用 JSON（单位字节）。
func MemoryStats() string {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	b, _ := json.Marshal(map[string]any{
		"heapAlloc":   ms.HeapAlloc,
		"heapSys":     ms.HeapSys,
		"totalSys":    ms.Sys,
		"memoryLimit": debug.SetMemoryLimit(-1),
	})
	return string(b)
}

// parseOverrides 解析覆写 JSON，空串返回零值
func parseOverrides(overridesJSON string) (coreOverrides, error) {
	var ov coreOverrides
	if overridesJSON == "" {
		return ov, nil
	}
	if err := json.Unmarshal([]byte(overridesJSON), &ov); err != nil {
		return ov, errors.New("覆写 JSON 解析失败: " + err.Error())
	}
	return ov, nil
}

// applyMemoryProtection 应用 GOMEMLIMIT 与 GOGC（D4）
func applyMemoryProtection(ov coreOverrides) {
	limitMiB := ov.GoMemLimitMiB
	if limitMiB <= 0 {
		limitMiB = defaultMemLimitMiB
	}
	debug.SetMemoryLimit(limitMiB << 20)

	gogc := ov.GoGC
	if gogc <= 0 {
		gogc = defaultGOGC
	}
	debug.SetGCPercent(gogc)
}

// buildRawConfig 解析 YAML 并应用覆写项中影响配置结构的部分（TUN fd、geodata 守卫）。
// 抽出为独立函数以便单测（applyConfig 调用它后再做控制器覆写与下发）。
func buildRawConfig(configYAML string, ov coreOverrides) (*config.RawConfig, error) {
	rawCfg, err := config.UnmarshalRawConfig([]byte(configYAML))
	if err != nil {
		return nil, err // yaml 解析错误自带行号定位
	}
	// 防护守卫：上游 DefaultRawConfig 已默认 memconservative，此处兜底防止空值（D4）
	if rawCfg.GeodataLoader == "" {
		rawCfg.GeodataLoader = "memconservative"
	}
	// TUN fd 注入（D3）：iOS NE 内由系统接管路由，内核仅用传入 fd 收发包。
	// 实战修复（demo 经验）：
	//   - 问题 7：iOS 沙盒不允许 system 栈 bind tun 地址，强制 gvisor 用户态栈（须配 -tags with_gvisor 构建）
	//   - 问题 9：auto-detect-interface 在沙盒用 socket 探测总命中蜂窝，关闭它，出站接口由 UpdateDefaultInterface 注入
	if ov.TunFD > 0 {
		rawCfg.Tun.Enable = true
		rawCfg.Tun.FileDescriptor = ov.TunFD
		rawCfg.Tun.Stack = mihomoConst.TunGvisor
		rawCfg.Tun.AutoRoute = false
		rawCfg.Tun.AutoDetectInterface = false
	}
	return rawCfg, nil
}

// applyConfig 解析 YAML 并应用到内核（Start 与 Reload 共用）
func applyConfig(configYAML string, ov coreOverrides) error {
	rawCfg, err := buildRawConfig(configYAML, ov)
	if err != nil {
		return err
	}
	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return err
	}
	if ov.ExternalController != "" {
		cfg.Controller.ExternalController = ov.ExternalController
	}
	if ov.Secret != "" {
		cfg.Controller.Secret = ov.Secret
	}
	hub.ApplyConfig(cfg)
	return nil
}

// startFreeOSMemoryTimer 周期性归还空闲内存给操作系统（D4）
func startFreeOSMemoryTimer() {
	freeOSStop = make(chan struct{})
	go func(stop chan struct{}) {
		ticker := time.NewTicker(freeOSInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				debug.FreeOSMemory()
			case <-stop:
				return
			}
		}
	}(freeOSStop)
}

// stopFreeOSMemoryTimer 停止归还定时器
func stopFreeOSMemoryTimer() {
	if freeOSStop != nil {
		close(freeOSStop)
		freeOSStop = nil
	}
}

// waitPortState 轮询等待 TCP 端口达到期望状态（open=true 等可达，false 等释放），超时返回 false
func waitPortState(addr string, open bool, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 200*time.Millisecond)
		if conn != nil {
			_ = conn.Close()
		}
		if (err == nil) == open {
			return true
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}

// waitControllerReady 轮询等待外部控制器 HTTP 服务就绪（鉴权 /version 返回 200），超时返回 false
func waitControllerReady(addr, secret string, timeout time.Duration) bool {
	client := &http.Client{Timeout: 500 * time.Millisecond}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		req, err := http.NewRequest("GET", "http://"+addr+"/version", nil)
		if err != nil {
			return false
		}
		if secret != "" {
			req.Header.Set("Authorization", "Bearer "+secret)
		}
		if resp, err := client.Do(req); err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return true
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}
