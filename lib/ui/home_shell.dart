import 'package:flutter/material.dart';

import '../core/apple_core_controller.dart';
import '../core/core_controller.dart';
import 'connect_shell.dart';
import 'kernel_settings_page.dart';
import 'settings_page.dart';

/// 应用主框架：持有共享 CoreController，底部导航切换 连接 / 设置 / 内核设置 三页。
/// 各页自带 Scaffold/AppBar（连接页含顶部 TabBar 整合节点/监控）；用 IndexedStack 保留各页状态。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, CoreController? controller})
    : _injectedController = controller;

  final CoreController? _injectedController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CoreController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget._injectedController ?? AppleCoreController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          ConnectShell(controller: _controller),
          const SettingsPage(),
          KernelSettingsPage(controller: _controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.power_settings_new),
            label: '连接',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: '内核设置'),
        ],
      ),
    );
  }
}
