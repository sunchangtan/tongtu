// Package mihomocore 是通途（Tongtu）的 mihomo 内核桥接层。
// 设计决策见 openspec/changes/p0-core-bridge/design.md：
//   - D2：导出接口收敛为粗粒度函数，复杂结构一律 JSON 字符串，便于 gomobile 绑定与多宿主复用
//   - D4：内存防护参数（GOMEMLIMIT/GOGC/memconservative/FreeOSMemory 定时器）集中在本包 Start 流程内应用
package mihomocore

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"sync"
	"time"

	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/config"
	mihomoConst "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/log"
	lumberjack "gopkg.in/natefinch/lumberjack.v2"
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
	LogDir             string `json:"log-dir"`             // 日志落盘目录（App Group 容器内），空则不落盘
	ConvertGeoRules    bool   `json:"convert-geo-rules"`   // 是否把 GEOSITE/GEOIP 转 mrs rule-set（iOS 启用，避免整库 geosite.dat 撑爆 NE 50MB）
}

// 日志滚动限容常量：硬约束「绝不无限增长」的唯一事实源，生产代码与测试共用，
// 避免两处各写一份 magic number 靠注释同步而失配。
const (
	logMaxSizeMiB = 1 // 单文件上限（MiB）
	logMaxBackups = 4 // 保留旧文件数（叠加当前文件，总量约 5 MiB 封顶）
)

var (
	mu            sync.Mutex
	state         = "stopped"
	lastOverrides coreOverrides // Reload 复用上次启动的覆写项
	freeOSStop    chan struct{}
	logSub        observable.Subscription[log.Event] // 内核日志订阅（落盘，供 stop 取消）
	logDone       chan struct{}                      // 落盘 goroutine 收尾信号
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
	// 日志落盘须在 applyConfig 之前订阅，确保捕获 proxy-provider 下载等最早日志
	startLogPersist(ov.LogDir)

	state = "starting"
	if err := applyConfig(configYAML, ov); err != nil {
		stopLogPersist() // 失败清理：避免日志订阅与落盘 goroutine 泄漏（回压会卡内核）
		state = "stopped"
		return err
	}
	// route 服务器异步启动（go start），等待控制器 HTTP 服务真正就绪后才算启动完成。
	// 用完整 HTTP 请求而非 TCP 拨测：保证上游 start() 已执行到 Serve（httpServer 赋值完成），
	// 规避上游 ReCreateServer 异步 goroutine 对全局 httpServer 的竞争窗口（详见 README 已知问题）。
	if ov.ExternalController != "" && !waitControllerReady(ov.ExternalController, ov.Secret, 3*time.Second) {
		stopLogPersist() // 失败清理：同上
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
	stopLogPersist()
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
	// geo 规则转 mrs rule-set（p1-geo-mrs-conversion）：把 GEOSITE/GEOIP 改写为按需 mrs，
	// 避免 mihomo eager 加载整库 geosite.dat（实测 +16.5MB Go 堆）撑爆 iOS NE 50MB 硬限。
	// 开关由调用方控制（iOS 启用），便于回滚到原行为。
	if ov.ConvertGeoRules {
		rewriteGeoRules(rawCfg)
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
		// TUN 通路必须 fake-ip 才能按域名分流（订阅作为完整配置消费，见
		// openspec/changes/p1-subscription-as-config design §9）
		applyFakeIPDNS(rawCfg)
	}
	// 不再自行注入 proxy-provider 缓存 path：mihomo 在 path 为空时已自动按 md5(url) 落盘缓存
	// 到 home-dir/proxies/（adapter/provider/parser.go），更强且尊重订阅显式 path；外网不可达
	// 时由该默认缓存提供回退（component/resource/fetcher.go Initial 的「本地→远程」回退）。
	return rawCfg, nil
}

// fake-ip 相关常量（唯一事实源，生产与测试共用）。
const fakeIPRange = "198.18.0.1/16"

// requiredFakeIPFilter 是 TUN+fake-ip 下必须直连真解析、不参与 fake-ip 的域名：
// 局域网 / 网络连通性探测 / Apple 推送 / 厂商探测 / NTP / STUN。并入订阅与上游已有 filter。
var requiredFakeIPFilter = []string{
	"*.lan", "*.local", "*.localhost",
	"localhost.ptlogin2.qq.com",
	"+.msftconnecttest.com", "+.msftncsi.com",
	"*.push.apple.com", "captive.apple.com",
	"connectivity-check.ubuntu.com",
	"+.market.xiaomi.com", "connect.rom.miui.com",
	"time.*.com", "time.*.apple.com", "+.pool.ntp.org",
	"stun.*.*", "stun.*.*.*",
}

// applyFakeIPDNS 在 TUN 模式强制注入 fake-ip 必需的 DNS 配置。
// 注意：config.UnmarshalRawConfig 以 DefaultRawConfig 为基底，DNS 各字段已预置上游默认值，
// 故不能用 len==0 判断「订阅是否自带」——对 fake-ip-filter 改为并集合并，确保必需域名
// （Apple 推送/局域网/STUN 等）始终生效；nameserver 沿用订阅或上游默认，无需补充。
func applyFakeIPDNS(rawCfg *config.RawConfig) {
	d := &rawCfg.DNS
	d.Enable = true
	d.EnhancedMode = mihomoConst.DNSFakeIP
	d.FakeIPRange = fakeIPRange
	d.FakeIPFilter = unionStrings(d.FakeIPFilter, requiredFakeIPFilter) // 保留已有 + 补必需
	if len(rawCfg.Tun.DNSHijack) == 0 {                                 // 劫持 53 端口进内核，否则应用直连公共 DNS 绕过 fake-ip
		rawCfg.Tun.DNSHijack = []string{"any:53"}
	}
	rawCfg.Profile.StoreFakeIP = true // 持久化 fake-ip 映射，防 NE 重启后 fake DNS record missing 断连
}

// unionStrings 返回 a、b 的有序去重并集（a 在前，保序）。
func unionStrings(a, b []string) []string {
	seen := make(map[string]struct{}, len(a)+len(b))
	out := make([]string, 0, len(a)+len(b))
	for _, group := range [][]string{a, b} {
		for _, s := range group {
			if _, ok := seen[s]; ok {
				continue
			}
			seen[s] = struct{}{}
			out = append(out, s)
		}
	}
	return out
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

// startLogPersist 订阅内核日志并滚动落盘（lumberjack）。
// 安全约束（取证 1.1）：内核日志 logCh 无缓冲、Emit 阻塞，慢消费会回压卡内核；
// 故用两级缓冲——goroutine A 用 select default 瞬时排空订阅（满则丢弃，绝不回压），
// goroutine B 慢写文件。日志非关键，宁丢不卡内核。
func startLogPersist(logDir string) {
	if logDir == "" {
		return
	}
	// 用局部变量供 goroutine 捕获：避免重复 Start 覆盖全局后，残留的旧 goroutine
	// 误关闭/误写当前轮的 channel 与 writer（防 close-of-closed-channel panic 与日志串档）。
	writer := &lumberjack.Logger{
		Filename:   filepath.Join(logDir, "core.log"),
		MaxSize:    logMaxSizeMiB, // 单文件上限
		MaxBackups: logMaxBackups, // 保留旧文件数（总量约 5 MiB 封顶，绝不无限增长）
		Compress:   false,
	}
	sub := log.Subscribe()
	done := make(chan struct{})
	internal := make(chan log.Event, 1000)
	go func() { // A：瞬时排空订阅，绝不回压内核
		for ev := range sub {
			select {
			case internal <- ev:
			default: // 内部缓冲满，丢弃以保护内核（宁丢日志不卡内核）
			}
		}
		close(internal)
	}()
	go func() { // B：从内部缓冲写文件（慢也只影响落盘，不回压内核）
		defer close(done)
		defer func() { _ = writer.Close() }() // 先于 close(done) 执行：done 信号时 writer 已关闭
		for ev := range internal {
			line := fmt.Sprintf("%s [%s] %s\n",
				time.Now().Format("2006-01-02T15:04:05.000"), ev.Type(), ev.Payload)
			_, _ = writer.Write([]byte(line))
		}
	}()
	// 全局仅记录当前轮，供 stopLogPersist 取消订阅与等待收尾
	logSub = sub
	logDone = done
}

// stopLogPersist 取消订阅并等待落盘 goroutine 收尾，最后关闭写入器。
func stopLogPersist() {
	if logSub == nil {
		return
	}
	log.UnSubscribe(logSub) // 关闭订阅 channel → A 退出 → close(internal) → B 退出（B 自行关闭 writer）
	<-logDone               // 等 B 收尾
	logSub = nil
	logDone = nil
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
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return true
			}
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}
