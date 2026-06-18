import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ondemand/ondemand_config.dart';
import '../ondemand/ondemand_controller.dart';
import '../ondemand/ondemand_store.dart';

/// 按需连接设置页：总开关 + 触发范围 + 信任 Wi-Fi 列表（增删 / 手动输入 / 读取当前）。
///
/// 关闭总开关时下方选项禁用；任何改动即时持久化并下发原生。
class OnDemandPage extends StatefulWidget {
  OnDemandPage({
    super.key,
    OnDemandStore? store,
    OnDemandController? controller,
  }) : store = store ?? OnDemandStore(),
       controller = controller ?? OnDemandController();

  final OnDemandStore store;
  final OnDemandController controller;

  @override
  State<OnDemandPage> createState() => _OnDemandPageState();
}

class _OnDemandPageState extends State<OnDemandPage> {
  OnDemandConfig _config = const OnDemandConfig.defaults();
  bool _loading = true;
  final TextEditingController _ssidInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ssidInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final OnDemandConfig cfg = await widget.store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = cfg;
      _loading = false;
    });
  }

  /// 更新状态并即时持久化 + 下发原生。
  Future<void> _apply(OnDemandConfig next) async {
    setState(() => _config = next);
    await widget.store.save(next);
    await widget.controller.update(next);
  }

  void _addSSID(String ssid) {
    final String trimmed = ssid.trim();
    if (trimmed.isEmpty || _config.trustedSSIDs.contains(trimmed)) {
      return;
    }
    _apply(
      _config.copyWith(
        trustedSSIDs: <String>[..._config.trustedSSIDs, trimmed],
      ),
    );
  }

  void _removeSSID(String ssid) {
    _apply(
      _config.copyWith(
        trustedSSIDs: _config.trustedSSIDs
            .where((String e) => e != ssid)
            .toList(),
      ),
    );
  }

  Future<void> _addCurrentWiFi() async {
    try {
      final String? ssid = await widget.controller.currentSSID();
      if (!mounted) {
        return;
      }
      if (ssid != null && ssid.isNotEmpty) {
        _addSSID(ssid);
      } else {
        _toast('未能获取当前 Wi-Fi 名称');
      }
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      _toast(
        e.code == 'denied'
            ? '需要定位权限才能读取 Wi-Fi 名称，请前往系统设置开启'
            : '未能获取当前 Wi-Fi 名称',
      );
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool on = _config.enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('按需连接')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('按需连接'),
                  subtitle: const Text('按网络条件自动启停隧道'),
                  value: on,
                  onChanged: (bool v) => _apply(_config.copyWith(enabled: v)),
                ),
                if (on)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '开启后，手动断开可能被系统按规则自动重连。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                _header('触发范围'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<OnDemandScope>(
                    segments: const <ButtonSegment<OnDemandScope>>[
                      ButtonSegment<OnDemandScope>(
                        value: OnDemandScope.all,
                        label: Text('全部'),
                      ),
                      ButtonSegment<OnDemandScope>(
                        value: OnDemandScope.wifiOnly,
                        label: Text('仅 WiFi'),
                      ),
                      ButtonSegment<OnDemandScope>(
                        value: OnDemandScope.cellularOnly,
                        label: Text('仅蜂窝'),
                      ),
                    ],
                    selected: <OnDemandScope>{_config.scope},
                    onSelectionChanged: on
                        ? (Set<OnDemandScope> s) =>
                              _apply(_config.copyWith(scope: s.first))
                        : null,
                  ),
                ),
                _header('信任的 Wi-Fi（这些网络下直连）'),
                ..._config.trustedSSIDs.map(
                  (String ssid) => ListTile(
                    title: Text(ssid),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: on ? () => _removeSSID(ssid) : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _ssidInput,
                          enabled: on,
                          decoration: const InputDecoration(
                            hintText: '手动输入 SSID',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: on
                            ? () {
                                _addSSID(_ssidInput.text);
                                _ssidInput.clear();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('添加当前 Wi-Fi'),
                    onPressed: on ? _addCurrentWiFi : null,
                  ),
                ),
              ],
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
