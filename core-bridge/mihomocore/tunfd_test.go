// TUN fd 注入测试（任务 4.3，D3：内核 TUN 栈 + fd 注入）
// 对应 specs/apple-packet-tunnel 的「TUN 数据通路」需求。
package mihomocore

import "testing"

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
