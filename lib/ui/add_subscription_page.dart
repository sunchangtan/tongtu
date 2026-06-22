import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tongtu/ui/icons/tongtu_icons.g.dart';

import '../config/subscription.dart';
import '../config/subscriptions_store.dart';
import 'scan_page.dart';

/// 全屏「添加订阅」页（对齐 clashmi 添加配置）：
/// - 名称（可选，默认 host）
/// - 输入框：订阅 URL **或**直接粘贴 clash 配置内容（自动识别）
/// - 导入来源：从剪贴板 / 扫码二维码
/// - 更新间隔（关闭 / 6h / 12h / 24h / 自定义≥5m）
/// - 自定义 User-Agent（默认 clash.meta）
///
/// [clipboardReader] / [scanner] 为测试注入点（默认读系统剪贴板 / push [ScanPage]）。
class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({
    super.key,
    required this.store,
    this.clipboardReader,
    this.scanner,
  });

  final SubscriptionsStore store;
  final Future<String?> Function()? clipboardReader;
  final Future<String?> Function(BuildContext context)? scanner;

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

// 更新间隔预设（分钟）；-1 表示「自定义」。
const int _intervalCustom = -1;
const List<(int, String)> _intervalPresets = <(int, String)>[
  (0, '关闭'),
  (360, '6 小时'),
  (720, '12 小时'),
  (1440, '24 小时'),
  (_intervalCustom, '自定义'),
];

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _uaCtrl = TextEditingController();
  final TextEditingController _customCtrl = TextEditingController();
  int _interval = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _nameCtrl.dispose();
    _inputCtrl.dispose();
    _uaCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final Future<String?> Function() reader =
        widget.clipboardReader ?? _defaultClipboard;
    final String? text = await reader();
    if (text != null && text.trim().isNotEmpty && mounted) {
      _inputCtrl.text = text.trim();
    }
  }

  static Future<String?> _defaultClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  Future<void> _scan() async {
    final Future<String?> Function(BuildContext) scan =
        widget.scanner ?? _defaultScanner;
    final String? text = await scan(context);
    if (text != null && text.trim().isNotEmpty && mounted) {
      _inputCtrl.text = text.trim();
    }
  }

  static Future<String?> _defaultScanner(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (BuildContext _) => const ScanPage()),
    );
  }

  /// 自定义间隔生效值：解析自定义分钟（<5 视为关闭）；否则取预设值。
  int get _effectiveInterval {
    if (_interval != _intervalCustom) {
      return _interval;
    }
    final int? m = int.tryParse(_customCtrl.text.trim());
    return (m != null && m >= 5) ? m : 0;
  }

  bool get _canSubmit => _inputCtrl.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    final String input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String name = _nameCtrl.text.trim();
    final SubscriptionInfo info;
    if (SubscriptionStore.isValidUrl(input)) {
      final String ua = _uaCtrl.text.trim();
      info = await widget.store.add(
        name.isEmpty ? (Uri.tryParse(input)?.host ?? '订阅') : name,
        input,
        userAgent: ua.isEmpty ? null : ua,
        intervalMinutes: _effectiveInterval,
      );
    } else {
      // 非 URL：当作直接粘贴的 clash 配置内容，本地校验入库
      info = await widget.store.addContent(name.isEmpty ? '本地配置' : name, input);
    }
    if (!mounted) {
      return;
    }
    if (info.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = info.message ?? '添加失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加订阅')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '订阅链接或直接粘贴配置内容',
                hintText: 'https://… 或 clash YAML',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(TongtuIcons.clipboard),
                    label: const Text('从剪贴板'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scan,
                    icon: const Icon(TongtuIcons.qrCode),
                    label: const Text('扫码'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text('更新间隔'),
                const Spacer(),
                DropdownButton<int>(
                  value: _interval,
                  onChanged: (int? v) {
                    if (v != null) {
                      setState(() => _interval = v);
                    }
                  },
                  items: _intervalPresets
                      .map(
                        ((int, String) p) => DropdownMenuItem<int>(
                          value: p.$1,
                          child: Text(p.$2),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            if (_interval == _intervalCustom) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '自定义间隔（分钟，≥5）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _uaCtrl,
              decoration: const InputDecoration(
                labelText: 'User-Agent（可选，默认 clash.meta）',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
