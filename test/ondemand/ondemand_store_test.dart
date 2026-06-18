import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/ondemand/ondemand_config.dart';
import 'package:tongtu/ondemand/ondemand_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDemandStore 持久化', () {
    test('无历史配置 load 返回缺省', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final OnDemandStore store = OnDemandStore();
      expect(await store.load(), const OnDemandConfig.defaults());
    });

    test('save 后 load 往返一致', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final OnDemandStore store = OnDemandStore();
      const OnDemandConfig cfg = OnDemandConfig(
        enabled: true,
        scope: OnDemandScope.wifiOnly,
        trustedSSIDs: <String>['Home'],
      );
      await store.save(cfg);
      expect(await store.load(), cfg);
    });

    test('损坏 JSON load 回退缺省（不抛异常）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        OnDemandStore.prefsKey: 'not-json{',
      });
      final OnDemandStore store = OnDemandStore();
      expect(await store.load(), const OnDemandConfig.defaults());
    });
  });
}
