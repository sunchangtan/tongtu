import 'package:flutter/material.dart';

import '../config/subscription.dart';
import '../config/subscriptions_store.dart';
import '../core/core_controller.dart';
import '../util/format.dart';

/// 订阅 tab（底部第 2 tab）：多订阅卡列表（名称 / 流量·到期 / 当前标记 / 更新 / 删除）+
/// 右下 FAB 添加（url + 名称，经 fetch 校验入库）+ 切换当前（已连接提示重连）+ 空态。
///
/// [store] 由 HomeShell 持有并注入（与连接页共享同一实例，[ChangeNotifier] 驱动跨页同步）；
/// [controller] 仅用于切换时判断是否已连接以提示重连。
class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({
    super.key,
    required this.store,
    required this.controller,
  });

  final SubscriptionsStore store;
  final CoreController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (BuildContext context, Widget? _) {
            final List<Subscription> subs = store.subscriptions;
            if (subs.isEmpty) {
              return _buildEmpty(context);
            }
            return ListView.builder(
              itemCount: subs.length,
              itemBuilder: (BuildContext context, int i) =>
                  _buildCard(context, subs[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        tooltip: '添加订阅',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 12),
          const Text('还没有订阅，点击右下角 + 添加'),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Subscription sub) {
    final bool isCurrent = sub.id == store.currentId;
    final Color accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        onTap: () => _switch(context, sub.id),
        leading: Icon(
          isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCurrent ? accent : Theme.of(context).disabledColor,
        ),
        title: Row(
          children: <Widget>[
            Flexible(child: Text(sub.name, overflow: TextOverflow.ellipsis)),
            if (isCurrent) ...<Widget>[
              const SizedBox(width: 8),
              _currentBadge(accent),
            ],
          ],
        ),
        subtitle: _buildSubtitle(sub.info),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: () => _update(context, sub.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: () => _delete(context, sub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentBadge(Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('当前', style: TextStyle(fontSize: 11, color: accent)),
  );

  Widget? _buildSubtitle(SubscriptionInfo? info) {
    if (info == null) {
      return null;
    }
    final List<String> lines = <String>[];
    final int? total = info.total;
    if (total != null) {
      final int used = (info.upload ?? 0) + (info.download ?? 0);
      lines.add('流量 ${formatBytes(used)} / ${formatBytes(total)}');
    }
    final int? expire = info.expire;
    if (expire != null && expire > 0) {
      lines.add('到期 ${_formatExpire(expire)}');
    }
    if (lines.isEmpty) {
      return null;
    }
    return Text(lines.join('　'), style: const TextStyle(fontSize: 12));
  }

  /// 切换当前订阅；若已连接则提示需重连（不自动断开）。
  Future<void> _switch(BuildContext context, String id) async {
    if (id == store.currentId) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool wasConnected = controller.state == CoreState.connected;
    await store.setCurrent(id);
    if (wasConnected) {
      messenger.showSnackBar(const SnackBar(content: Text('已切换订阅，请断开后重连生效')));
    }
  }

  Future<void> _add(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => _AddSubscriptionDialog(store: store),
    );
  }

  Future<void> _update(BuildContext context, String id) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SubscriptionInfo info = await store.update(id);
    messenger.showSnackBar(
      SnackBar(content: Text(info.ok ? '订阅已更新' : '更新失败：${info.message ?? ''}')),
    );
  }

  Future<void> _delete(BuildContext context, Subscription sub) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('确定删除「${sub.name}」？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await store.remove(sub.id);
    messenger.showSnackBar(const SnackBar(content: Text('订阅已删除')));
  }

  static String _formatExpire(int unixSeconds) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
    );
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// 添加订阅弹窗：名称（可选，默认 url 主机名）+ 订阅链接，经 [SubscriptionsStore.add]
/// fetch 校验；成功关闭弹窗，失败在弹窗内显示原因。
class _AddSubscriptionDialog extends StatefulWidget {
  const _AddSubscriptionDialog({required this.store});

  final SubscriptionsStore store;

  @override
  State<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<_AddSubscriptionDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String url = _urlCtrl.text.trim();
    if (!SubscriptionStore.isValidUrl(url)) {
      setState(() => _error = '订阅链接无效：必须是 http/https 链接');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String name = _nameCtrl.text.trim().isEmpty
        ? (Uri.tryParse(url)?.host ?? '订阅')
        : _nameCtrl.text.trim();
    final SubscriptionInfo info = await widget.store.add(name, url);
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
    return AlertDialog(
      title: const Text('添加订阅'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '订阅链接',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('添加'),
        ),
      ],
    );
  }
}
