/// 通用格式化工具：按 1024 进制把数值缩放为带单位的可读字符串。
/// 流量大小与速率共用同一缩放逻辑，单位表与小数位由调用方决定，避免多处各写一份。
library;

/// 按 1024 进制缩放为带单位的字符串。
/// [units] 自小到大排列、末项为最大单位；[decimals] 为非基础单位的小数位
/// （基础单位 B 级别恒取整数，避免「512.0 B」这类冗余小数）。
String formatScaled(num value, List<String> units, {int decimals = 1}) {
  double v = value.toDouble();
  int unit = 0;
  while (v >= 1024 && unit < units.length - 1) {
    v /= 1024;
    unit++;
  }
  return '${v.toStringAsFixed(unit == 0 ? 0 : decimals)} ${units[unit]}';
}

/// 字节数 → 可读大小（B/KB/MB/GB/TB，非基础单位保留 2 位小数）。
String formatBytes(int bytes) => formatScaled(bytes, const <String>[
  'B',
  'KB',
  'MB',
  'GB',
  'TB',
], decimals: 2);

/// 速率 → 可读速率（B/s…MB/s，非基础单位保留 1 位小数）。
String formatRate(int bytesPerSec) =>
    formatScaled(bytesPerSec, const <String>['B/s', 'KB/s', 'MB/s']);
