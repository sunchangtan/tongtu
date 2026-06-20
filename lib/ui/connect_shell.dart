import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../config/subscriptions_store.dart';
import '../core/core_controller.dart';
import 'home_page.dart';
import 'monitor_page.dart';
import 'nodes_page.dart';

/// 连接首页：顶部 TabBar 整合 连接 / 节点 / 监控 三子页（复用现有页面，逻辑不动）。
/// 用 IndexedStack 承载，切换子页保留各页状态（监控数据流/节点列表不重建、不重订阅）。
class ConnectShell extends StatefulWidget {
  const ConnectShell({
    super.key,
    required this.controller,
    required this.store,
    required this.runParams,
  });

  final CoreController controller;
  final SubscriptionsStore store;
  final RunParamsStore runParams;

  @override
  State<ConnectShell> createState() => _ConnectShellState();
}

class _ConnectShellState extends State<ConnectShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.index != _index) {
        setState(() => _index = _tab.index);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // 去标题栏，仅保留底部 TabBar 子导航
        bottom: TabBar(
          controller: _tab,
          tabs: const <Widget>[
            Tab(text: '连接'),
            Tab(text: '节点'),
            Tab(text: '监控'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomePage(
            controller: widget.controller,
            store: widget.store,
            runParams: widget.runParams,
          ),
          NodesPage(controller: widget.controller, runParams: widget.runParams),
          MonitorPage(controller: widget.controller),
        ],
      ),
    );
  }
}
