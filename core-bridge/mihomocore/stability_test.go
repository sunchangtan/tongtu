// 启停稳定性测试（任务 4.5）：反复启停验证无 fd/端口泄漏、每轮冷启动状态干净。
// 内核侧的权威验证（iOS 扩展进程退出已在真机观察）。
package mihomocore

import (
	"os"
	"testing"
)

// openFDCount 统计当前进程打开的文件描述符数（Darwin 下读 /dev/fd）。
// 用 Readdirnames 而非 ReadDir：后者会 lstat 每个条目，包括它自己打开的目录 fd，
// 在 /dev/fd 上会触发 "bad file descriptor"。
func openFDCount(t *testing.T) int {
	t.Helper()
	f, err := os.Open("/dev/fd")
	if err != nil {
		t.Fatalf("打开 /dev/fd 失败: %v", err)
	}
	defer func() { _ = f.Close() }()
	names, err := f.Readdirnames(-1)
	if err != nil {
		t.Fatalf("读取 /dev/fd 失败: %v", err)
	}
	return len(names)
}

// 场景：反复启停 20 次 —— 每轮状态干净、端口可复用、无 fd 泄漏
func TestStartStopStability(t *testing.T) {
	const cycles = 20
	port := freePort(t)
	ov := overrides(t, port, "stability-secret")

	var baselineFD int
	for i := 0; i < cycles; i++ {
		if err := Start(validConfig, ov); err != nil {
			t.Fatalf("第 %d 轮 Start 失败: %v", i+1, err)
		}
		if got := State(); got != "running" {
			t.Fatalf("第 %d 轮启动后状态应为 running，实际 %q", i+1, got)
		}
		if err := Stop(); err != nil {
			t.Fatalf("第 %d 轮 Stop 失败: %v", i+1, err)
		}
		if got := State(); got != "stopped" {
			t.Fatalf("第 %d 轮停止后状态应为 stopped，实际 %q", i+1, got)
		}
		// 跳过前几轮预热（内核首次加载有缓存/池初始化），第 5 轮记基线
		if i == 4 {
			baselineFD = openFDCount(t)
		}
	}

	// 稳定期后 fd 数不应显著增长（容忍少量运行时抖动）
	finalFD := openFDCount(t)
	if finalFD > baselineFD+5 {
		t.Errorf("疑似 fd 泄漏：基线 %d，20 轮后 %d", baselineFD, finalFD)
	}
}
