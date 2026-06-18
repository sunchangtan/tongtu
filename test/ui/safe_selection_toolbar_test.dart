import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/safe_selection_toolbar.dart';

void main() {
  group('resolveSafeAnchors', () {
    test('compute 正常时透传框架锚点', () {
      const TextSelectionToolbarAnchors expected = TextSelectionToolbarAnchors(
        primaryAnchor: Offset(5, 5),
      );
      final TextSelectionToolbarAnchors got = resolveSafeAnchors(
        () => expected,
        Offset.zero,
      );
      expect(got.primaryAnchor, const Offset(5, 5));
    });

    test(
      'compute 抛 null-check TypeError 时回退到 fallback（模拟框架 startSelectionPoint! 崩溃）',
      () {
        final TextSelectionToolbarAnchors got = resolveSafeAnchors(() {
          // 运行时 null 强解，等价框架 startSelectionPoint!.lineHeight 的 _TypeError。
          final List<TextSelectionToolbarAnchors?> box =
              <TextSelectionToolbarAnchors?>[null];
          return box.first!;
        }, const Offset(10, 20));
        expect(got.primaryAnchor, const Offset(10, 20));
      },
    );
  });
}
