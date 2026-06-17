import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/app_theme.dart';
import 'package:tongtu/ui/tokens/tokens.g.dart';

void main() {
  group('AppTheme 引用生成 token', () {
    test('浅色品牌关键角色取自 TongtuSysColorsLight', () {
      final ColorScheme s = AppTheme.lightScheme;
      expect(s.brightness, Brightness.light);
      expect(s.primary, TongtuSysColorsLight.primary);
      expect(s.primary, const Color(0xFF3F51B5)); // 品牌靛蓝
      expect(s.secondary, TongtuSysColorsLight.secondary);
      expect(s.secondary, const Color(0xFF1E9BD4)); // 品牌蓝青
      expect(s.surface, TongtuSysColorsLight.surface);
      expect(s.onSurface, TongtuSysColorsLight.onSurface);
      expect(s.error, TongtuSysColorsLight.error);
    });

    test('深色品牌关键角色取自 TongtuSysColorsDark', () {
      final ColorScheme s = AppTheme.darkScheme;
      expect(s.brightness, Brightness.dark);
      expect(s.primary, TongtuSysColorsDark.primary);
      expect(s.primary, const Color(0xFFBBC3FF));
      expect(s.surface, TongtuSysColorsDark.surface);
      expect(s.surface, const Color(0xFF15161B));
    });

    test('明暗 primary / surface 取值不同', () {
      expect(AppTheme.lightScheme.primary, isNot(AppTheme.darkScheme.primary));
      expect(AppTheme.lightScheme.surface, isNot(AppTheme.darkScheme.surface));
    });

    test('主题启用 Material 3', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
    });
  });
}
