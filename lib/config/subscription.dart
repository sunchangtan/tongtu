import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 订阅拉取结果（流量/到期来自 subscription-userinfo 响应头，字节 / Unix 秒）。
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.ok,
    this.message,
    this.content,
    this.upload,
    this.download,
    this.total,
    this.expire,
  });

  final bool ok;
  final String? message;

  /// 订阅返回的完整 clash 配置正文（ok 时有效），作为内核主配置传入。
  final String? content;
  final int? upload;
  final int? download;
  final int? total;
  final int? expire;

  /// 仅覆盖给定字段，其余沿用原值——避免新增字段时漏改手工组装点。
  SubscriptionInfo copyWith({bool? ok, String? message, String? content}) {
    return SubscriptionInfo(
      ok: ok ?? this.ok,
      message: message ?? this.message,
      content: content ?? this.content,
      upload: upload,
      download: download,
      total: total,
      expire: expire,
    );
  }
}

/// 订阅管理（M1 最小：单订阅，链接持久化于 SharedPreferences，完整配置正文落文件）。
class SubscriptionStore {
  /// [configDir] 为配置正文落盘目录的提供者（测试可注入临时目录）；默认 app 支持目录。
  SubscriptionStore({Future<Directory> Function()? configDir})
    : _configDir = configDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _configDir;

  static const String _key = 'subscription_url';
  static const String _contentSourceKey = 'subscription_content_url';

  /// 合法 clash 配置标记：顶层须含 `proxies:` 或 `proxy-providers:`（行首锚定，
  /// 避免注释/字符串/HTML 错误页里出现字样导致的子串误判）。
  static final RegExp _clashConfigMarker = RegExp(
    r'^(proxies|proxy-providers):',
    multiLine: true,
  );

  /// 校验是否为合法 http/https 订阅链接。
  static bool isValidUrl(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
  }

  /// 保存订阅链接；非 http/https 链接抛 FormatException（中文消息）。
  Future<void> save(String url) async {
    if (!isValidUrl(url)) {
      throw const FormatException('订阅链接无效：必须是 http/https 链接');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url.trim());
  }

  /// 读取已保存的订阅链接（无则返回 null）。
  Future<String?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<File> _contentFile() async {
    final Directory dir = await _configDir();
    return File('${dir.path}/subscription.yaml');
  }

  /// 保存订阅完整配置正文（落文件）与其来源 url（存 prefs，供连接前一致性校验）。
  Future<void> saveContent(String content, String sourceUrl) async {
    final File f = await _contentFile();
    await f.writeAsString(content);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentSourceKey, sourceUrl.trim());
  }

  /// 读取已保存的订阅完整配置正文（无则返回 null）。
  Future<String?> loadContent() async {
    final File f = await _contentFile();
    return f.existsSync() ? await f.readAsString() : null;
  }

  /// 读取已保存正文的来源 url（无则返回 null）。
  Future<String?> loadContentSourceUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_contentSourceKey);
  }

  /// 获取配置：HTTP 拉取订阅，校验为合法 clash 配置并返回完整正文（作为内核主配置），
  /// 同时解析 subscription-userinfo 流量/到期信息。
  Future<SubscriptionInfo> fetch(String url, {http.Client? client}) async {
    final String trimmed = url.trim();
    if (!isValidUrl(trimmed)) {
      return const SubscriptionInfo(
        ok: false,
        message: '订阅链接无效：必须是 http/https 链接',
      );
    }
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response resp = await httpClient
          .get(
            Uri.parse(trimmed),
            headers: <String, String>{'User-Agent': 'clash.meta'},
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        return SubscriptionInfo(
          ok: false,
          message: '获取失败：HTTP ${resp.statusCode}',
        );
      }
      final String body = resp.body;
      // 行首锚定校验：合法 clash 配置须有顶层 proxies / proxy-providers
      if (!_clashConfigMarker.hasMatch(body)) {
        return const SubscriptionInfo(
          ok: false,
          message: '订阅内容非合法 clash 配置（缺顶层 proxies / proxy-providers）',
        );
      }
      return _parseUserInfo(
        resp.headers['subscription-userinfo'],
      ).copyWith(ok: true, content: body);
    } on Exception catch (e) {
      return SubscriptionInfo(ok: false, message: '获取失败：${e.runtimeType}');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// 解析 subscription-userinfo 头：upload=..; download=..; total=..; expire=..
  static SubscriptionInfo _parseUserInfo(String? header) {
    if (header == null || header.isEmpty) {
      return const SubscriptionInfo(ok: true, message: '订阅可达（无流量信息）');
    }
    final Map<String, int> fields = <String, int>{};
    for (final String part in header.split(';')) {
      final List<String> kv = part.trim().split('=');
      if (kv.length == 2) {
        final int? value = int.tryParse(kv[1].trim());
        if (value != null) {
          fields[kv[0].trim()] = value;
        }
      }
    }
    return SubscriptionInfo(
      ok: true,
      message: '订阅可达',
      upload: fields['upload'],
      download: fields['download'],
      total: fields['total'],
      expire: fields['expire'],
    );
  }
}
