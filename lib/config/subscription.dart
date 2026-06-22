import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

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

/// 订阅拉取与校验（无状态）：HTTP 拉取订阅、校验为合法 clash 配置、解析流量·到期。
/// 持久化与多订阅管理由 `SubscriptionsStore` 负责（本类不落盘）。
class SubscriptionStore {
  /// 校验为合法 clash 配置：能解析为 YAML 映射且含**非空** proxies 或 proxy-providers。
  /// 用真 YAML 解析（而非子串匹配），杜绝注释/HTML 错误页里出现字样的误判，并能识别
  /// `proxies: []` 空列表；返回 null 表示合法，否则返回中文原因。连接时内核 Start 仍会终校验兜底。
  static String? _validateClashConfig(String body) {
    final dynamic doc;
    try {
      doc = loadYaml(body);
    } catch (_) {
      return 'YAML 解析失败';
    }
    if (doc is! Map) {
      return '内容不是有效的 YAML 配置';
    }
    final dynamic proxies = doc['proxies'];
    final dynamic providers = doc['proxy-providers'];
    final bool hasProxies = proxies is List && proxies.isNotEmpty;
    final bool hasProviders = providers is Map && providers.isNotEmpty;
    if (!hasProxies && !hasProviders) {
      return '缺少节点：proxies / proxy-providers 为空或不存在';
    }
    return null;
  }

  /// 校验是否为合法 http/https 订阅链接。
  static bool isValidUrl(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
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
      // 用真 YAML 解析校验（杜绝子串误判）；连接时内核 Start 仍会终校验兜底
      final String? invalidReason = _validateClashConfig(body);
      if (invalidReason != null) {
        return SubscriptionInfo(ok: false, message: '订阅内容非合法配置：$invalidReason');
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
