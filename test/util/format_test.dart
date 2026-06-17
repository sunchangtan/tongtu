import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/util/format.dart';

void main() {
  group('formatBytes（B/KB/MB/GB/TB，非基础单位 2 位小数）', () {
    test('0 与 B 级别取整数（不出现冗余小数）', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('逐级进位并保留 2 位小数', () {
      expect(formatBytes(1024), '1.00 KB');
      expect(formatBytes(1536), '1.50 KB');
      expect(formatBytes(1024 * 1024), '1.00 MB');
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });

    test('超大值钳制在最大单位 TB，不溢出单位表', () {
      const int pb = 1024 * 1024 * 1024 * 1024 * 1024; // 1 PB
      expect(formatBytes(pb), '1024.00 TB');
    });
  });

  group('formatRate（B/s…MB/s，非基础单位 1 位小数）', () {
    test('B/s 取整、KB/s 起保留 1 位小数', () {
      expect(formatRate(0), '0 B/s');
      expect(formatRate(800), '800 B/s');
      expect(formatRate(1024), '1.0 KB/s');
      expect(formatRate(1536), '1.5 KB/s');
      expect(formatRate(1024 * 1024), '1.0 MB/s');
    });

    test('超大速率钳制在最大单位 MB/s', () {
      expect(formatRate(5 * 1024 * 1024 * 1024), '5120.0 MB/s');
    });
  });

  group('formatScaled（通用缩放）', () {
    test('decimals 参数控制非基础单位小数位', () {
      expect(
        formatScaled(1536, const <String>['B', 'KB'], decimals: 3),
        '1.500 KB',
      );
    });

    test('1024 边界恰好进位', () {
      expect(formatScaled(1024, const <String>['B', 'KB']), '1.0 KB');
    });
  });
}
