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
	if logSub != nil || logDone != nil {
		t.Fatal("空目录不应初始化落盘")
	}
	stopLogPersist()
}

// 场景：重复 start/stop 配对不 panic，且 stop 后全局清空、重复 stop 幂等
// （守护修复：goroutine 捕获局部 writer/sub/done，不因重复 Start 误关上一轮
//  channel 触发 close-of-closed-channel panic；stopLogPersist 首句 nil 判空幂等）。
func TestLogPersist_RepeatStartStopNoPanic(t *testing.T) {
	dir := t.TempDir()
	for i := 0; i < 5; i++ {
		startLogPersist(dir) // 同一目录反复开关，兼测重开同一 core.log 不出错
		for j := 0; j < 20; j++ {
			log.Warnln("轮次-%d-日志-%d", i, j)
		}
		stopLogPersist() // 同步等本轮 goroutine 收尾
		if logSub != nil || logDone != nil {
			t.Fatalf("第 %d 轮 stop 后全局应清空", i)
		}
	}
	stopLogPersist() // 已停止状态重复 stop，幂等不 panic
}

// 场景：连续两轮落盘到不同目录，各自独立、互不串档
// （守护修复：writer 为 goroutine 捕获的局部变量，旧轮不会写进新目录、新轮不写回旧目录）。
func TestLogPersist_NoCrossContamination(t *testing.T) {
	dir1 := t.TempDir()
	startLogPersist(dir1)
	for i := 0; i < 30; i++ {
		log.Warnln("第一轮-标记-%d", i)
	}
	stopLogPersist()

	dir2 := t.TempDir()
	startLogPersist(dir2)
	for i := 0; i < 30; i++ {
		log.Warnln("第二轮-标记-%d", i)
	}
	stopLogPersist()

	d1, err := os.ReadFile(filepath.Join(dir1, "core.log"))
	if err != nil {
		t.Fatalf("读第一轮日志失败: %v", err)
	}
	d2, err := os.ReadFile(filepath.Join(dir2, "core.log"))
	if err != nil {
		t.Fatalf("读第二轮日志失败: %v", err)
	}
	if !strings.Contains(string(d1), "第一轮-标记") {
		t.Error("第一轮目录缺少第一轮日志")
	}
	if strings.Contains(string(d1), "第二轮-标记") {
		t.Error("第一轮目录串入第二轮日志（writer 未隔离）")
	}
	if !strings.Contains(string(d2), "第二轮-标记") {
		t.Error("第二轮目录缺少第二轮日志")
	}
	if strings.Contains(string(d2), "第一轮-标记") {
		t.Error("第二轮目录串入第一轮日志（writer 未隔离）")
	}
}

// 场景：滚动限容 —— 大量写入后文件数与总大小封顶，绝不无限增长
func TestLogRotation_CapsTotalSize(t *testing.T) {
	dir := t.TempDir()
	w := &lumberjack.Logger{
		Filename: filepath.Join(dir, "core.log"),
		// 直接复用生产常量：保证测的就是 startLogPersist 实际滚动配置，而非另写一份
		MaxSize:    logMaxSizeMiB,
		MaxBackups: logMaxBackups,
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
