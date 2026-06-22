import 'package:flutter/material.dart';
import 'package:tongtu/ui/icons/tongtu_icons.g.dart';

import '../config/run_params_store.dart';
import '../config/subscriptions_store.dart';
import '../core/apple_core_controller.dart';
import '../core/core_controller.dart';
import 'connect_shell.dart';
import 'settings_page.dart';
import 'subscriptions_page.dart';

/// 应用主框架：持有共享 CoreController / SubscriptionsStore / RunParamsStore，底部导航切换
/// 连接 / 订阅 / 设置 三页。各页自带 Scaffold（连接页含顶部 TabBar 整合节点/监控；
/// 内核设置降为设置 tab 的二级入口）；用 IndexedStack 保留各页状态。
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    CoreController? controller,
    SubscriptionsStore? store,
    RunParamsStore? runParams,
  }) : _injectedController = controller,
       _injectedStore = store,
       _injectedRunParams = runParams;

  final CoreController? _injectedController;
  final SubscriptionsStore? _injectedStore;
  final RunParamsStore? _injectedRunParams;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CoreController _controller;
  late final SubscriptionsStore _store;
  late final RunParamsStore _runParams;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget._injectedController ?? AppleCoreController();
    _store = widget._injectedStore ?? SubscriptionsStore();
    _runParams = widget._injectedRunParams ?? RunParamsStore();
    _init();
  }

  /// 加载订阅与运行参数偏好；首次从当前订阅配置种子化运行参数（升级不回归）；
  /// 启动时对到期订阅做自动更新（尽力、失败不阻塞）。
  Future<void> _init() async {
    await _store.load();
    await _runParams.load();
    final String? content = await _store.currentContent();
    if (content != null && content.isNotEmpty) {
      await _runParams.seedFromConfig(content); // 幂等：已持久化则 no-op
    }
    await _store.runDueAutoUpdates(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _store.dispose();
    _runParams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          ConnectShell(
            controller: _controller,
            store: _store,
            runParams: _runParams,
          ),
          SubscriptionsPage(store: _store, controller: _controller),
          SettingsPage(
            controller: _controller,
            runParams: _runParams,
            store: _store,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(TongtuIcons.power), label: '连接'),
          NavigationDestination(icon: Icon(TongtuIcons.cloud), label: '订阅'),
          NavigationDestination(icon: Icon(TongtuIcons.settings), label: '设置'),
        ],
      ),
    );
  }
}
