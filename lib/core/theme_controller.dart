import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局主题控制器：主题模式状态（ValueNotifier）+ shared_preferences 持久化。
/// `main.dart` 用 ValueListenableBuilder 包 MaterialApp 触发重建；设置页切换即时生效 + 存盘。
final ThemeController themeController = ThemeController();

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  static const String _key = 'theme_mode';

  /// app 启动时读取持久化的主题模式（缺省跟随系统）。
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    value = _parse(prefs.getString(_key));
  }

  /// 切换并持久化主题模式。
  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static ThemeMode _parse(String? s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
