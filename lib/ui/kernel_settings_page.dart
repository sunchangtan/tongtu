import 'dart:async';

import 'package:flutter/material.dart';

import '../config/run_params_store.dart';
import '../config/subscriptions_store.dart';
import '../core/app_info.dart';
import '../core/clash_api.dart';
import '../core/core_controller.dart';
import 'config_viewer_page.dart';
import 'log_viewer_page.dart';
import 'rules_page.dart';

/// 内核设置页（设置 tab 的二级入口，push 进入，有 AppBar 标题与返回）：
/// - 运行参数（store 驱动的预设偏好，**未连接也可改**，改后「需重连生效」）：
///   日志级别 / IPv6 / 统一延迟 / TCP 并发 / 域名嗅探 / 局域网接入 + 混合端口
///   （运行模式在连接首页）
/// - 维护动作（**连接中**才可用，作用于运行中内核）：更新 GEO / 清 fake-ip / 清 DNS 缓存
/// - 配置与规则：查看订阅配置 / 分流规则
/// - 内核信息：内核版本 / 日志
class KernelSettingsPage extends StatefulWidget {
  const KernelSettingsPage({
    super.key,
    required this.controller,
    required this.runParams,
    required this.store,
    this.apiFactory,
  });

  final CoreController controller;
  final RunParamsStore runParams;
  final SubscriptionsStore store; // 提供「查看订阅配置」的当前正文

  /// 测试注入点：由 endpoint 构造 ClashApi（默认 ClashApi.new），仅维护动作用。
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

class _KernelSettingsPageState extends State<KernelSettingsPage> {
  StreamSubscription<CoreState>? _stateSub; // dispose 取消，防泄漏
  ClashApi? _api; // 仅维护动作用（作用于运行中内核）
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.controller.stateStream.listen((CoreState state) {
      if (!mounted) {
        return;
      }
      setState(() => _connected = state == CoreState.connected);
      if (state != CoreState.connected) {
        _api?.dispose();
        _api = null;
      }
    });
    if (widget.controller.state == CoreState.connected) {
      _connected = true;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _api?.dispose();
    super.dispose();
  }

  ClashApi? _ensureApi() {
    final ControllerEndpoint? endpoint = widget.controller.currentEndpoint;
    if (endpoint == null) {
      return null;
    }
    return _api ??= (widget.apiFactory ?? ClashApi.new)(endpoint);
  }

  RunParams get _p => widget.runParams.params;

  Future<void> _save(RunParams next) => widget.runParams.save(next);

  Future<void> _maintain(
    Future<void> Function(ClashApi api) action,
    String okMsg,
  ) async {
    final ClashApi? api = _ensureApi();
    if (api == null) {
      return;
    }
    try {
      await action(api);
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

  /// 通用文本编辑弹窗：返回修剪后的输入；取消返回 null。
  Future<String?> _promptText(
    String title,
    String initial, {
    TextInputType? keyboardType,
    String? hint,
  }) async {
    final TextEditingController ctrl = TextEditingController(text: initial);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _editMixedPort() async {
    final String? s = await _promptText(
      '混合端口',
      '${_p.mixedPort}',
      keyboardType: TextInputType.number,
      hint: '如 7890',
    );
    final int? port = int.tryParse(s ?? '');
    if (port != null && port > 0 && port < 65536) {
      await _save(_p.copyWith(mixedPort: port));
    }
  }

  Future<void> _editDelayUrl() async {
    final String? s = await _promptText(
      '延迟测试 URL',
      _p.delayTestUrl,
      keyboardType: TextInputType.url,
      hint: 'http://...',
    );
    if (s != null && s.isNotEmpty) {
      await _save(_p.copyWith(delayTestUrl: s));
    }
  }

  Future<void> _editDelayTimeout() async {
    final String? s = await _promptText(
      '延迟测试超时(ms)',
      '${_p.delayTestTimeoutMs}',
      keyboardType: TextInputType.number,
      hint: '如 5000',
    );
    final int? t = int.tryParse(s ?? '');
    if (t != null && t > 0) {
      await _save(_p.copyWith(delayTestTimeoutMs: t));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内核设置')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.runParams,
          builder: (BuildContext context, Widget? _) => ListView(
            children: <Widget>[
              _header('运行参数'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '修改后需重连生效',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              _buildLogLevel(),
              SwitchListTile(
                title: const Text('IPv6'),
                value: _p.ipv6,
                onChanged: (bool v) => _save(_p.copyWith(ipv6: v)),
              ),
              SwitchListTile(
                title: const Text('统一延迟'),
                subtitle: const Text('延迟去除握手耗时，更接近真实'),
                value: _p.unifiedDelay,
                onChanged: (bool v) => _save(_p.copyWith(unifiedDelay: v)),
              ),
              SwitchListTile(
                title: const Text('TCP 并发'),
                subtitle: const Text('多 IP 并发握手，取最快'),
                value: _p.tcpConcurrent,
                onChanged: (bool v) => _save(_p.copyWith(tcpConcurrent: v)),
              ),
              SwitchListTile(
                title: const Text('域名嗅探'),
                subtitle: const Text('从流量嗅探域名，改善按域名分流'),
                value: _p.sniff,
                onChanged: (bool v) => _save(_p.copyWith(sniff: v)),
              ),
              _header('局域网代理共享'),
              SwitchListTile(
                title: const Text('局域网接入'),
                subtitle: const Text('允许同网段设备经本机为代理网关（需真机验证）'),
                value: _p.allowLan,
                onChanged: (bool v) => _save(_p.copyWith(allowLan: v)),
              ),
              ListTile(
                enabled: _p.allowLan,
                title: const Text('混合端口'),
                subtitle: Text('${_p.mixedPort}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _p.allowLan ? _editMixedPort : null,
              ),
              _header('延迟测试'),
              ListTile(
                title: const Text('延迟测试 URL'),
                subtitle: Text(_p.delayTestUrl),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editDelayUrl,
              ),
              ListTile(
                title: const Text('延迟测试超时'),
                subtitle: Text('${_p.delayTestTimeoutMs} ms'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editDelayTimeout,
              ),
              _header('维护（连接中可用）'),
              ListTile(
                enabled: _connected,
                leading: const Icon(Icons.public),
                title: const Text('更新 GEO 数据库'),
                onTap: _connected
                    ? () =>
                          _maintain((ClashApi a) => a.updateGeo(), 'GEO 更新已触发')
                    : null,
              ),
              ListTile(
                enabled: _connected,
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清 fake-ip 缓存'),
                onTap: _connected
                    ? () => _maintain(
                        (ClashApi a) => a.flushFakeIP(),
                        'fake-ip 缓存已清',
                      )
                    : null,
              ),
              ListTile(
                enabled: _connected,
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清 DNS 缓存'),
                onTap: _connected
                    ? () => _maintain((ClashApi a) => a.flushDNS(), 'DNS 缓存已清')
                    : null,
              ),
              _header('配置与规则'),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('查看订阅配置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) =>
                        ConfigViewerPage(loader: widget.store.currentContent),
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
      ),
    );
  }

  Widget _buildLogLevel() {
    final String level = _logLevels.contains(_p.logLevel)
        ? _p.logLevel
        : 'info';
    return ListTile(
      title: const Text('日志级别'),
      trailing: DropdownButton<String>(
        value: level,
        onChanged: (String? v) {
          if (v != null) {
            _save(_p.copyWith(logLevel: v));
          }
        },
        items: _logLevels
            .map(
              (String l) => DropdownMenuItem<String>(value: l, child: Text(l)),
            )
            .toList(),
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
