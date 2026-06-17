import 'dart:io';

import 'package:flutter/services.dart';

/// 日志文件存取：经原生 channel 取 App Group 日志目录，用 dart:io 读全量日志
/// （含 lumberjack 滚动 backups，按时间合并）、定位导出路径、清空。
/// 完整历史以落盘文件为准（内存只留最近 N 条），可回看最早（含 provider 下载）与跨会话。
class LogStore {
  LogStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.dingqi.tongtu/core');

  final MethodChannel _channel;

  /// 取 App Group 日志目录绝对路径（由原生 containerURL 返回）。
  Future<String?> logDirPath() => _channel.invokeMethod<String>('logDir');

  /// 按修改时间排序的日志文件（旧 → 新）。
  Future<List<File>> _logFiles() async {
    final String? dir = await logDirPath();
    if (dir == null) {
      return <File>[];
    }
    final Directory d = Directory(dir);
    if (!d.existsSync()) {
      return <File>[];
    }
    final List<File> files = d
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.log'))
        .toList();
    files.sort(
      (File a, File b) =>
          a.statSync().modified.compareTo(b.statSync().modified),
    );
    return files;
  }

  /// 读全量日志（含 backups，按时间合并：旧在前、最新在后）。
  Future<String> readAll() async {
    final List<File> files = await _logFiles();
    final StringBuffer sb = StringBuffer();
    for (final File f in files) {
      sb.write(await f.readAsString());
    }
    return sb.toString();
  }

  /// 当前主日志文件路径（导出用），无则返回 null。
  Future<String?> currentLogFile() async {
    final List<File> files = await _logFiles();
    return files.isEmpty ? null : files.last.path;
  }

  /// 清空所有日志文件。
  Future<void> clear() async {
    for (final File f in await _logFiles()) {
      try {
        await f.delete();
      } on FileSystemException {
        // 删除失败忽略（可能正被内核写入）
      }
    }
  }
}
