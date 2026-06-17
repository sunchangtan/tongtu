import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/core_controller.dart';
import '../core/theme_controller.dart';
import 'config_viewer_page.dart';
import 'log_viewer_page.dart';
import 'rules_page.dart';

/// 设置页（底部第 4 tab）：外观主题 / 配置查看 / 分流规则 / 关于。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final CoreController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
        _header('配置与规则'),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('查看订阅配置'),
          subtitle: const Text('只读查看订阅原文'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const ConfigViewerPage(),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.rule_outlined),
          title: const Text('分流规则'),
          subtitle: const Text('查看内核生效规则'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => RulesPage(controller: controller),
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
          leading: Icon(Icons.memory),
          title: Text('内核版本'),
          subtitle: Text('mihomo $kMihomoVersion'),
        ),
        const ListTile(
          leading: Icon(Icons.balance),
          title: Text('开源许可'),
          subtitle: Text('GPL-3.0'),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('日志'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const LogViewerPage(),
            ),
          ),
        ),
      ],
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
