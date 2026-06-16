import 'package:shared_preferences/shared_preferences.dart';

/// 订阅管理（M1 最小：单订阅链接，持久化于 SharedPreferences）。
class SubscriptionStore {
  static const String _key = 'subscription_url';

  /// 保存订阅链接；非 http/https 链接抛 FormatException（中文消息）。
  Future<void> save(String url) async {
    final String trimmed = url.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    final bool valid =
        uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
    if (!valid) {
      throw const FormatException('订阅链接无效：必须是 http/https 链接');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }

  /// 读取已保存的订阅链接（无则返回 null）。
  Future<String?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
