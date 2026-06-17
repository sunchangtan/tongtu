// 日志落盘与滚动限容测试（p1-log-system 任务 1.4）
// 对应 openspec/changes/p1-log-system/specs/runtime-logging 的
// 「内核日志全量落盘」「日志文件滚动限容」需求。
package mihomocore

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
	lumberjack "gopkg.in/natefinch/lumberjack.v2"
)

// 场景：内核启动即落盘 —— 订阅后产生的日志写入 core.log
func TestLogPersist_WritesToFile(t *testing.T) {
	dir := t.TempDir()
	startLogPersist(dir)
	for i := 0; i < 50; i++ {
		log.Warnln("落盘测试日志-%d", i)
	}
	stopLogPersist() // 同步等落盘 goroutine 收尾，确保写完

	data, err := os.ReadFile(filepath.Join(dir, "core.log"))
	if err != nil {
		t.Fatalf("读日志文件失败: %v", err)
	}
	if !strings.Contains(string(data), "落盘测试日志") {
		t.Fatalf("日志文件未包含预期内容")
	}
}

// 场景：空目录不落盘（不订阅，避免无谓回压风险）；stop 幂等不 panic
func TestLogPersist_EmptyDirNoop(t *testing.T) {
	startLogPersist("")
	if logSub != nil || logWriter != nil {
		t.Fatal("空目录不应初始化落盘")
	}
	stopLogPersist()
}

// 场景：滚动配置正确 —— 单文件 1 MiB、保留 4 个旧文件
func TestLogPersist_RotationConfig(t *testing.T) {
	dir := t.TempDir()
	startLogPersist(dir)
	defer stopLogPersist()
	if logWriter == nil {
		t.Fatal("logWriter 未初始化")
	}
	if logWriter.MaxSize != 1 {
		t.Errorf("MaxSize=%d, 期望 1 MiB", logWriter.MaxSize)
	}
	if logWriter.MaxBackups != 4 {
		t.Errorf("MaxBackups=%d, 期望 4", logWriter.MaxBackups)
	}
}

// 场景：滚动限容 —— 大量写入后文件数与总大小封顶，绝不无限增长
func TestLogRotation_CapsTotalSize(t *testing.T) {
	dir := t.TempDir()
	w := &lumberjack.Logger{
		Filename:   filepath.Join(dir, "core.log"),
		MaxSize:    1, // 与 startLogPersist 一致
		MaxBackups: 4,
	}
	line := []byte(strings.Repeat("x", 1024) + "\n")
	for i := 0; i < 6*1024; i++ { // 写约 6 MiB，触发多次滚动
		if _, err := w.Write(line); err != nil {
			t.Fatalf("写日志失败: %v", err)
		}
	}
	_ = w.Close()

	// lumberjack 在后台 goroutine 异步删除超量 backup；poll 等其收敛到上限内
	// （condition-based waiting，避免固定 sleep 的 flaky，也不放水断言）
	var entries []os.DirEntry
	for i := 0; i < 40; i++ {
		entries, _ = os.ReadDir(dir)
		if len(entries) <= 5 {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	var total int64
	for _, e := range entries {
		info, _ := e.Info()
		total += info.Size()
	}
	// MaxSize=1 MiB + MaxBackups=4 → 最多 5 个文件、总量约 5 MiB
	if len(entries) > 5 {
		t.Fatalf("日志文件数 %d 超过上限 5（滚动限容失效）", len(entries))
	}
	if total > 6*1024*1024 {
		t.Fatalf("日志总大小 %d 字节超过封顶（不应无限增长）", total)
	}
	t.Logf("滚动后文件数=%d 总大小=%d KiB", len(entries), total/1024)
}
