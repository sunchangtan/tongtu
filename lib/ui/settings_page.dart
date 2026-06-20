import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../core/app_info.dart';
import '../core/core_controller.dart';
import '../core/theme_controller.dart';
import 'kernel_settings_page.dart';
import 'ondemand_page.dart';

/// 设置页（应用层，底部第 3 tab）：外观主题 / 按需连接 / 内核设置（二级入口）/ 关于。
/// 无 AppBar 标题（底部导航已标识当前页）；内核运行参数·维护·配置规则在内核设置二级页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.runParams,
  });

  final CoreController controller;
  final RunParamsStore runParams;

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
            _header('内核'),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('内核设置'),
              subtitle: const Text('运行参数 / 维护 / 配置规则 / 内核信息'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => KernelSettingsPage(
                    controller: controller,
                    runParams: runParams,
                  ),
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
