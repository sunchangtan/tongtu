import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ondemand_config.dart';

/// 按需连接配置的本地持久化（`shared_preferences`，JSON 序列化）。
class OnDemandStore {
  /// 持久化键。
  static const String prefsKey = 'ondemand_config';

  /// 读取配置；无历史或数据损坏时回退 [OnDemandConfig.defaults]。
  Future<OnDemandConfig> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(prefsKey);
    if (raw == null) {
      return const OnDemandConfig.defaults();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OnDemandConfig.fromJson(decoded);
      }
    } on FormatException {
      // 持久化数据损坏：回退缺省（落到下方），不向上抛。
    }
    return const OnDemandConfig.defaults();
  }

  /// 保存配置。
  Future<void> save(OnDemandConfig config) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(config.toJson()));
  }
}
