import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/clash_api.dart';
import '../core/core_controller.dart';
import 'config_viewer_page.dart';
import 'log_viewer_page.dart';
import 'rules_page.dart';

/// 内核设置页（底部第 3 tab）：
/// - 运行参数（连接中经 `PATCH /configs` 热改、立即生效）：运行模式 / 日志级别 / IPv6
/// - 维护动作（连接中）：更新 GEO / 清 fake-ip / 清 DNS 缓存
/// - 配置与规则：查看订阅配置 / 分流规则（复用现有页）
/// - 内核信息：内核版本 / unified-delay（只读）/ 日志
class KernelSettingsPage extends StatefulWidget {
  const KernelSettingsPage({
    super.key,
    required this.controller,
    this.apiFactory,
  });

  final CoreController controller;

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new）。
  final ClashApi Function(ControllerEndpoint)? apiFactory;

  @override
  State<KernelSettingsPage> createState() => _KernelSettingsPageState();
}

const List<String> _logLevels = <String>[
  'info',
  'warning',
  'error',
  'debug',
  'silent',
];

const List<String> _modes = <String>['rule', 'global', 'direct'];

class _KernelSettingsPageState extends State<KernelSettingsPage> {
  StreamSubscription<CoreState>? _stateSub; // dispose 取消，防泄漏
  ClashApi? _api;
  KernelConfig? _config;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      final bool connected = state == CoreState.connected;
      setState(() => _connected = connected);
      if (connected) {
        _loadConfigs();
      } else {
        setState(() => _config = null);
      }
    });
    if (widget.controller.state == CoreState.connected) {
      _connected = true;
      _loadConfigs();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _api?.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return;
    }
    _api?.dispose(); // 重连换 endpoint 前释放旧 http client，防泄漏
    final ClashApi api = (widget.apiFactory ?? ClashApi.new)(endpoint);
    _api = api;
    try {
      final KernelConfig cfg = await api.getConfigs();
      if (mounted) {
        setState(() => _config = cfg);
      }
    } on Exception catch (e) {
      // on Exception 而非仅 ClashApiException：断连时底层抛 SocketException 等，避免裸抛崩溃
      _toast('读取内核配置失败：$e');
    }
  }

  /// 热改运行参数：乐观更新 + 失败回滚。
  Future<void> _patch(
    Map<String, dynamic> fields,
    KernelConfig optimistic,
  ) async {
    final ClashApi? api = _api;
    if (api == null) {
      return;
    }
    final KernelConfig? prev = _config;
    setState(() => _config = optimistic);
    try {
      await api.patchConfigs(fields);
    } on Exception catch (e) {
      // 仅在仍连接时回滚：断连时 _config 已被 stateStream 置 null，回滚会覆盖回旧值造成脏状态
      if (mounted && _connected) {
        setState(() => _config = prev);
        _toast('修改失败：$e');
      }
    }
  }

  Future<void> _maintain(Future<void> Function() action, String okMsg) async {
    if (_api == null) {
      return;
    }
    try {
      await action();
      _toast(okMsg);
    } on Exception catch (e) {
      _toast('操作失败：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final KernelConfig? cfg = _config;
    final bool ready = _connected && cfg != null; // 运行参数可调
    // 防御：内核返回的值若不在固定选项内，回退默认，否则 DropdownButton/SegmentedButton 断言崩
    final String logLevel = cfg?.logLevel ?? 'info';
    final String safeLogLevel = _logLevels.contains(logLevel)
        ? logLevel
        : 'info';
    final String mode = cfg?.mode ?? 'rule';
    final String safeMode = _modes.contains(mode) ? mode : 'rule';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            _header('运行参数'),
            if (!_connected)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('连接后可调', style: TextStyle(color: Colors.grey)),
              ),
            ListTile(
              enabled: ready,
              title: const Text('运行模式'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'rule', label: Text('规则')),
                    ButtonSegment<String>(value: 'global', label: Text('全局')),
                    ButtonSegment<String>(value: 'direct', label: Text('直连')),
                  ],
                  selected: <String>{safeMode},
                  onSelectionChanged: ready
                      ? (Set<String> s) => _patch(
                          <String, dynamic>{'mode': s.first},
                          KernelConfig(
                            mode: s.first,
                            logLevel: cfg.logLevel,
                            ipv6: cfg.ipv6,
                            unifiedDelay: cfg.unifiedDelay,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            ListTile(
              enabled: ready,
              title: const Text('日志级别'),
              trailing: DropdownButton<String>(
                value: safeLogLevel,
                onChanged: ready
                    ? (String? v) {
                        if (v != null) {
                          _patch(
                            <String, dynamic>{'log-level': v},
                            KernelConfig(
                              mode: cfg.mode,
                              logLevel: v,
                              ipv6: cfg.ipv6,
                              unifiedDelay: cfg.unifiedDelay,
                            ),
                          );
                        }
                      }
                    : null,
                items: _logLevels
                    .map(
                      (String l) =>
                          DropdownMenuItem<String>(value: l, child: Text(l)),
                    )
                    .toList(),
              ),
            ),
            SwitchListTile(
              title: const Text('IPv6'),
              value: cfg?.ipv6 ?? false,
              onChanged: ready
                  ? (bool v) => _patch(
                      <String, dynamic>{'ipv6': v},
                      KernelConfig(
                        mode: cfg.mode,
                        logLevel: cfg.logLevel,
                        ipv6: v,
                        unifiedDelay: cfg.unifiedDelay,
                      ),
                    )
                  : null,
            ),
            _header('维护'),
            ListTile(
              enabled: _connected,
              leading: const Icon(Icons.public),
              title: const Text('更新 GEO 数据库'),
              onTap: _connected
                  ? () => _maintain(() => _api!.updateGeo(), 'GEO 更新已触发')
                  : null,
            ),
            ListTile(
              enabled: _connected,
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('清 fake-ip 缓存'),
              onTap: _connected
                  ? () => _maintain(() => _api!.flushFakeIP(), 'fake-ip 缓存已清')
                  : null,
            ),
            ListTile(
              enabled: _connected,
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('清 DNS 缓存'),
              onTap: _connected
                  ? () => _maintain(() => _api!.flushDNS(), 'DNS 缓存已清')
                  : null,
            ),
            _header('配置与规则'),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('查看订阅配置'),
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
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) =>
                      RulesPage(controller: widget.controller),
                ),
              ),
            ),
            _header('内核信息'),
            const ListTile(
              leading: Icon(Icons.memory),
              title: Text('内核版本'),
              subtitle: Text('mihomo $kMihomoVersion'),
            ),
            if (ready)
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('unified-delay'),
                subtitle: Text(cfg.unifiedDelay ? '开' : '关'),
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
