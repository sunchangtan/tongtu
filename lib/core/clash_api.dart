import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'core_controller.dart';

/// 代理组（Selector 等含候选节点的组）。
class ProxyGroup {
  const ProxyGroup({
    required this.name,
    required this.type,
    required this.now,
    required this.all,
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) {
    return ProxyGroup(
      name: name,
      type: json['type'] as String? ?? '',
      now: json['now'] as String? ?? '',
      all: (json['all'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    );
  }

  final String name;
  final String type;
  final String now;
  final List<String> all;

  bool get isSelector => type == 'Selector';
}

/// 实时流量速率（字节/秒）。
class Traffic {
  const Traffic({required this.up, required this.down});

  factory Traffic.fromJson(Map<String, dynamic> json) {
    return Traffic(
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
    );
  }

  final int up;
  final int down;
}

/// 内核日志条目。
class LogEntry {
  LogEntry({required this.type, required this.payload, DateTime? time})
    : time = time ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    // 刻意不传 time：mihomo /logs 不下发时间戳，由构造函数默认取「收到时刻」。
    return LogEntry(
      type: json['type'] as String? ?? 'info',
      payload: json['payload'] as String? ?? '',
    );
  }

  final String type;
  final String payload;

  /// 接收时刻（mihomo /logs 不带时间，用主 App 收到的时刻）。
  final DateTime time;
}

/// 活动连接条目。
class ConnectionItem {
  const ConnectionItem({
    required this.host,
    required this.chains,
    required this.rule,
    required this.upload,
    required this.download,
  });

  factory ConnectionItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta =
        (json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String hostName = (meta['host'] as String?) ?? '';
    final String host = hostName.isNotEmpty
        ? hostName
        : '${meta['destinationIP'] ?? ''}:${meta['destinationPort'] ?? ''}';
    return ConnectionItem(
      host: host,
      chains: (json['chains'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      rule: json['rule'] as String? ?? '',
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
    );
  }

  final String host;
  final List<String> chains;
  final String rule;
  final int upload;
  final int download;
}

/// clash-api 调用异常。
class ClashApiException implements Exception {
  ClashApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// mihomo external-controller 客户端（REST + WebSocket，Bearer secret 鉴权）。
class ClashApi {
  ClashApi(this._endpoint, {http.Client? client})
    : _client = client ?? http.Client();

  final ControllerEndpoint _endpoint;
  final http.Client _client;

  Map<String, String> get _headers => <String, String>{
    'Authorization': 'Bearer ${_endpoint.secret}',
  };

  Uri _rest(String path, [Map<String, dynamic>? query]) {
    final Uri base = Uri.parse('${_endpoint.baseUrl()}$path');
    if (query == null) {
      return base;
    }
    return base.replace(
      queryParameters: query.map(
        (String k, dynamic v) => MapEntry<String, String>(k, '$v'),
      ),
    );
  }

  /// 查询代理组（仅返回含候选节点的组，如 Selector）。
  Future<Map<String, ProxyGroup>> getProxyGroups() async {
    final http.Response resp = await _client.get(
      _rest('/proxies'),
      headers: _headers,
    );
    if (resp.statusCode != 200) {
      throw ClashApiException('查询代理失败：HTTP ${resp.statusCode}');
    }
    final Map<String, dynamic> body =
        jsonDecode(resp.body) as Map<String, dynamic>;
    final Map<String, dynamic> proxies =
        (body['proxies'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, ProxyGroup> groups = <String, ProxyGroup>{};
    proxies.forEach((String name, dynamic value) {
      final Map<String, dynamic> node = value as Map<String, dynamic>;
      final List<dynamic>? all = node['all'] as List<dynamic>?;
      if (all != null && all.isNotEmpty) {
        groups[name] = ProxyGroup.fromJson(name, node);
      }
    });
    return groups;
  }

  /// 切换 select 组的选中节点。
  Future<void> selectProxy(String group, String name) async {
    final http.Response resp = await _client.put(
      _rest('/proxies/${Uri.encodeComponent(group)}'),
      headers: _headers,
      body: jsonEncode(<String, String>{'name': name}),
    );
    if (resp.statusCode != 204 && resp.statusCode != 200) {
      throw ClashApiException('切换节点失败：HTTP ${resp.statusCode}');
    }
  }

  /// 对节点测延迟（毫秒）；失败抛 ClashApiException。
  Future<int> testDelay(
    String name, {
    String url = 'http://www.gstatic.com/generate_204',
    int timeout = 5000,
  }) async {
    final http.Response resp = await _client.get(
      _rest('/proxies/${Uri.encodeComponent(name)}/delay', <String, dynamic>{
        'url': url,
        'timeout': timeout,
      }),
      headers: _headers,
    );
    if (resp.statusCode != 200) {
      throw ClashApiException('延迟测试失败：HTTP ${resp.statusCode}');
    }
    final Map<String, dynamic> body =
        jsonDecode(resp.body) as Map<String, dynamic>;
    return (body['delay'] as num?)?.toInt() ?? 0;
  }

  /// 查询当前活动连接快照。
  Future<List<ConnectionItem>> getConnections() async {
    final http.Response resp = await _client.get(
      _rest('/connections'),
      headers: _headers,
    );
    if (resp.statusCode != 200) {
      throw ClashApiException('查询连接失败：HTTP ${resp.statusCode}');
    }
    final Map<String, dynamic> body =
        jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> conns =
        (body['connections'] as List<dynamic>?) ?? <dynamic>[];
    return conns
        .map((dynamic c) => ConnectionItem.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// 实时流量速率（WebSocket）。
  Stream<Traffic> trafficStream() =>
      _wsStream('/traffic').map(Traffic.fromJson);

  /// 实时日志（WebSocket）。
  Stream<LogEntry> logsStream() => _wsStream('/logs').map(LogEntry.fromJson);

  Stream<Map<String, dynamic>> _wsStream(String path) async* {
    final Uri uri = Uri.parse(
      '${_endpoint.baseUrl(websocket: true)}$path',
    ).replace(queryParameters: <String, String>{'token': _endpoint.secret});
    final WebSocketChannel channel = WebSocketChannel.connect(uri);
    // 先等连接就绪：连接被拒（内核 controller 未就绪）时错误在此抛出并纳入本 stream，
    // 交由订阅方 onError 处理，避免 channel.ready 的未捕获 future 错误（debugger 中断/崩溃）。
    try {
      await channel.ready;
    } on Exception catch (e) {
      throw ClashApiException('WebSocket 连接失败：$e');
    }
    yield* channel.stream.map(
      (dynamic event) => jsonDecode(event as String) as Map<String, dynamic>,
    );
  }

  void dispose() {
    _client.close();
  }
}
