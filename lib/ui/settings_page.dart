import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/theme_controller.dart';
import 'ondemand_page.dart';

/// 设置页（应用层，底部第 2 tab）：外观主题 / 按需连接 / 关于（app 版本·许可）。
/// 无 AppBar 标题（底部导航已标识当前页）；内核相关项已移至内核设置页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            _header('外观'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeController,
              builder: (BuildContext context, ThemeMode mode, Widget? _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('系统'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('亮'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('暗'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: <ThemeMode>{mode},
                    onSelectionChanged: (Set<ThemeMode> s) =>
                        themeController.setMode(s.first),
                  ),
                );
              },
            ),
            _header('网络'),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('按需连接'),
              subtitle: const Text('按网络条件自动启停隧道'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => OnDemandPage(),
                ),
              ),
            ),
            _header('关于'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('应用版本'),
              subtitle: Text(kAppVersion),
            ),
            const ListTile(
              leading: Icon(Icons.balance),
              title: Text('开源许可'),
              subtitle: Text('GPL-3.0'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
