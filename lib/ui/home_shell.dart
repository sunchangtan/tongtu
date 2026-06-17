import 'package:flutter/material.dart';

import '../core/apple_core_controller.dart';
import '../core/core_controller.dart';
import 'home_page.dart';
import 'monitor_page.dart';
import 'nodes_page.dart';
import 'settings_page.dart';

/// 应用主框架：持有共享 CoreController，底部导航切换 连接 / 节点 / 监控 / 设置 四页。
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

  static const List<String> _titles = <String>['通途', '节点', '监控', '设置'];

  @override
  void initState() {
    super.initState();
    _controller = widget._injectedController ?? AppleCoreController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomePage(controller: _controller),
          NodesPage(controller: _controller),
          MonitorPage(controller: _controller),
          SettingsPage(controller: _controller),
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
          NavigationDestination(icon: Icon(Icons.dns_outlined), label: '节点'),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: '监控',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
