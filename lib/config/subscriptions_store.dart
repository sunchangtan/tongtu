import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription.dart';

/// 单条订阅：id（落盘文件名/选中键）、名称、url、流量·到期信息（info，可空）。
/// 配置正文不入此对象——按 id 落盘 `configs/<id>.yaml`，避免 prefs JSON 膨胀。
class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.info,
  });

  final String id;
  final String name;
  final String url;

  /// 最近一次拉取的流量·到期等元信息（不含正文）；未拉取过为 null。
  final SubscriptionInfo? info;

  /// 仅覆盖给定字段（id/url 不变），其余沿用原值。
  Subscription copyWith({String? name, SubscriptionInfo? info}) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      url: url,
      info: info ?? this.info,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    if (info != null) 'info': _infoToJson(info!),
  };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    info: json['info'] is Map
        ? _infoFromJson((json['info'] as Map).cast<String, dynamic>())
        : null,
  );
}

/// 仅持久化 info 的元信息（流量/到期/状态），不含 content（正文落盘）。
Map<String, dynamic> _infoToJson(SubscriptionInfo info) => <String, dynamic>{
  'ok': info.ok,
  if (info.message != null) 'message': info.message,
  if (info.upload != null) 'upload': info.upload,
  if (info.download != null) 'download': info.download,
  if (info.total != null) 'total': info.total,
  if (info.expire != null) 'expire': info.expire,
};

SubscriptionInfo _infoFromJson(Map<String, dynamic> json) => SubscriptionInfo(
  ok: json['ok'] as bool? ?? true,
  message: json['message'] as String?,
  upload: json['upload'] as int?,
  download: json['download'] as int?,
  total: json['total'] as int?,
  expire: json['expire'] as int?,
);

/// 多订阅管理：订阅列表 + 当前选中（currentId）持久化于 SharedPreferences（JSON），
/// 每条订阅的配置正文按 id 落盘 `configs/<id>.yaml`。
///
/// 依赖可注入（测试友好）：
/// - [configDir]：落盘根目录提供者，默认 app 支持目录；
/// - [idGen]：新订阅 id 生成器，默认微秒时间戳；
/// - [fetcher]：按 url 拉取并校验配置，默认复用 [SubscriptionStore.fetch]。
///
/// 为 [ChangeNotifier]：成功变更（增/删/切换/更新）后通知监听者，供连接页/订阅页跨页同步
/// （如订阅页加首条后连接页按钮即时启用）。
class SubscriptionsStore extends ChangeNotifier {
  SubscriptionsStore({
    Future<Directory> Function()? configDir,
    String Function()? idGen,
    Future<SubscriptionInfo> Function(String url)? fetcher,
  }) : _configDir = configDir ?? getApplicationSupportDirectory,
       _idGen =
           idGen ?? (() => DateTime.now().microsecondsSinceEpoch.toString()),
       _fetcher = fetcher ?? ((String url) => SubscriptionStore().fetch(url));

  final Future<Directory> Function() _configDir;
  final String Function() _idGen;
  final Future<SubscriptionInfo> Function(String url) _fetcher;

  static const String _subsKey = 'subscriptions';
  static const String _currentKey = 'subscription_current';

  List<Subscription> _subscriptions = <Subscription>[];
  String? _currentId;

  /// 订阅列表（只读视图，外部不可变更）。
  List<Subscription> get subscriptions =>
      List<Subscription>.unmodifiable(_subscriptions);

  /// 当前选中订阅 id（无则 null）。
  String? get currentId => _currentId;

  /// 加载持久化的订阅列表与当前选中。完成后通知监听者，供 HomeShell 异步 load 后各页刷新。
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _subscriptions = _decodeList(prefs.getString(_subsKey));
    _currentId = prefs.getString(_currentKey);
    notifyListeners();
  }

  /// 添加订阅：先经 [fetcher] 拉取并校验，校验失败（ok=false）不入库、原样返回；
  /// 成功则入库、落盘正文、列表空时自动设为当前，并持久化。
  Future<SubscriptionInfo> add(String name, String url) async {
    final SubscriptionInfo info = await _fetcher(url);
    if (!info.ok) {
      return info; // 校验失败不入库
    }
    final String id = _idGen();
    _subscriptions = <Subscription>[
      ..._subscriptions,
      Subscription(id: id, name: name, url: url, info: info),
    ];
    if (info.content != null) {
      await _writeContent(id, info.content!);
    }
    _currentId ??= id; // 首条自动设为当前
    await _persist();
    notifyListeners();
    return info;
  }

  /// 删除订阅：移除其落盘正文；若删的是当前选中，则转移到列表首项（空则清空）。
  Future<void> remove(String id) async {
    _subscriptions = _subscriptions
        .where((Subscription s) => s.id != id)
        .toList();
    final File f = await _contentFile(id);
    if (f.existsSync()) {
      await f.delete();
    }
    if (_currentId == id) {
      _currentId = _subscriptions.isEmpty ? null : _subscriptions.first.id;
    }
    await _persist();
    notifyListeners();
  }

  /// 切换当前选中（已是当前则无变更；id 不存在则忽略）。
  Future<void> setCurrent(String id) async {
    if (_currentId == id) {
      return;
    }
    if (!_subscriptions.any((Subscription s) => s.id == id)) {
      return;
    }
    _currentId = id;
    await _persist();
    notifyListeners();
  }

  /// 更新订阅：按 url 重新拉取，成功则刷新 info 与落盘正文；失败保留原配置、原样返回。
  Future<SubscriptionInfo> update(String id) async {
    final int idx = _subscriptions.indexWhere((Subscription s) => s.id == id);
    if (idx < 0) {
      return const SubscriptionInfo(ok: false, message: '订阅不存在');
    }
    final SubscriptionInfo info = await _fetcher(_subscriptions[idx].url);
    if (!info.ok) {
      return info; // 拉取失败保留原配置
    }
    _subscriptions[idx] = _subscriptions[idx].copyWith(info: info);
    if (info.content != null) {
      await _writeContent(id, info.content!);
    }
    await _persist();
    notifyListeners();
    return info;
  }

  /// 当前选中订阅的配置正文（无当前选中或正文缺失返回 null）。
  Future<String?> currentContent() async {
    final String? id = _currentId;
    if (id == null) {
      return null;
    }
    final File f = await _contentFile(id);
    return f.existsSync() ? await f.readAsString() : null;
  }

  // ── 内部 ──────────────────────────────────────────────────────────

  Future<File> _contentFile(String id) async {
    final Directory dir = await _configDir();
    return File('${dir.path}/configs/$id.yaml');
  }

  Future<void> _writeContent(String id, String content) async {
    final File f = await _contentFile(id);
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  List<Subscription> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Subscription>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Subscription>[];
      }
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                Subscription.fromJson(m.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return <Subscription>[]; // 损坏的 JSON 视为空，避免启动崩溃
    }
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> list = _subscriptions
        .map((Subscription s) => s.toJson())
        .toList();
    await prefs.setString(_subsKey, jsonEncode(list));
    final String? id = _currentId;
    if (id != null) {
      await prefs.setString(_currentKey, id);
    } else {
      await prefs.remove(_currentKey);
    }
  }
}
