// TUN fd 注入测试（任务 4.3，D3：内核 TUN 栈 + fd 注入）
// 对应 specs/apple-packet-tunnel 的「TUN 数据通路」需求。
package mihomocore

import (
	"testing"

	mihomoConst "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/component/dialer"
)

// 场景：注入 tun-fd —— 生成的配置启用 TUN 并使用传入的 fd（iOS NE 内 packetFlow 取到的 fd）
func TestTunFDInjection(t *testing.T) {
	ov := coreOverrides{TunFD: 42}
	rawCfg, err := buildRawConfig(validConfig, ov)
	if err != nil {
		t.Fatalf("buildRawConfig 失败: %v", err)
	}
	if !rawCfg.Tun.Enable {
		t.Error("注入 tun-fd 后 TUN 应启用")
	}
	if rawCfg.Tun.FileDescriptor != 42 {
		t.Errorf("TUN file-descriptor 应为 42，实际为 %d", rawCfg.Tun.FileDescriptor)
	}
	// iOS NE 内由系统接管路由，内核不得自行 auto-route
	if rawCfg.Tun.AutoRoute {
		t.Error("注入外部 fd 时不应启用 auto-route（路由由 NE 接管）")
	}
	// 问题 9：auto-detect-interface 在 NE 沙盒误判蜂窝，必须关闭
	if rawCfg.Tun.AutoDetectInterface {
		t.Error("注入外部 fd 时不应启用 auto-detect-interface（沙盒探测误判蜂窝）")
	}
	// 问题 7：iOS 沙盒不允许 system 栈 bind tun 地址，必须强制 gvisor 用户态栈
	if rawCfg.Tun.Stack != mihomoConst.TunGvisor {
		t.Errorf("注入外部 fd 时 TUN 栈应强制为 gvisor，实际为 %v", rawCfg.Tun.Stack)
	}
}

// 问题 9：UpdateDefaultInterface 设置内核出站绑定的接口名
func TestUpdateDefaultInterface(t *testing.T) {
	UpdateDefaultInterface("en0")
	if got := dialer.DefaultInterface.Load(); got != "en0" {
		t.Errorf("出站默认接口应为 en0，实际为 %q", got)
	}
	UpdateDefaultInterface("") // 复位避免污染其他测试
}

// 场景：未注入 tun-fd —— 保持配置原样（不强制开启 TUN）
func TestNoTunFDKeepsConfig(t *testing.T) {
	rawCfg, err := buildRawConfig(validConfig, coreOverrides{})
	if err != nil {
		t.Fatalf("buildRawConfig 失败: %v", err)
	}
	if rawCfg.Tun.Enable {
		t.Error("未注入 tun-fd 时不应自动启用 TUN")
	}
}
