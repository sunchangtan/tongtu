import 'package:http/http.dart' as http;
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
}

/// 订阅管理（M1 最小：单订阅链接，持久化于 SharedPreferences）。
class SubscriptionStore {
  static const String _key = 'subscription_url';
  static const String _contentKey = 'subscription_content';

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

  /// 保存订阅完整配置正文（作为内核主配置，连接时读取传入内核）。
  Future<void> saveContent(String content) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentKey, content);
  }

  /// 读取已保存的订阅完整配置正文（无则返回 null）。
  Future<String?> loadContent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_contentKey);
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
      // 校验为合法 clash 配置：须含 proxies 或 proxy-providers，否则不作为配置写入
      if (!body.contains('proxies') && !body.contains('proxy-providers')) {
        return const SubscriptionInfo(
          ok: false,
          message: '订阅内容非合法 clash 配置（缺 proxies / proxy-providers）',
        );
      }
      final SubscriptionInfo info = _parseUserInfo(
        resp.headers['subscription-userinfo'],
      );
      return SubscriptionInfo(
        ok: true,
        message: info.message,
        content: body,
        upload: info.upload,
        download: info.download,
        total: info.total,
        expire: info.expire,
      );
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
