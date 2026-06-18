import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ondemand/ondemand_config.dart';

void main() {
  group('OnDemandConfig 语义模型', () {
    test('缺省配置：关闭 / 全部 / 空信任列表', () {
      const cfg = OnDemandConfig.defaults();
      expect(cfg.enabled, isFalse);
      expect(cfg.scope, OnDemandScope.all);
      expect(cfg.trustedSSIDs, isEmpty);
    });

    test('toJson/fromJson 往返一致', () {
      const cfg = OnDemandConfig(
        enabled: true,
        scope: OnDemandScope.wifiOnly,
        trustedSSIDs: <String>['Home', 'Office'],
      );
      final OnDemandConfig back = OnDemandConfig.fromJson(cfg.toJson());
      expect(back, cfg);
    });

    test('scope 序列化为稳定字符串名', () {
      const cfg = OnDemandConfig(
        enabled: false,
        scope: OnDemandScope.cellularOnly,
        trustedSSIDs: <String>[],
      );
      expect(cfg.toJson()['scope'], 'cellularOnly');
    });

    test('fromJson 未知 scope 回退为 all', () {
      final OnDemandConfig cfg = OnDemandConfig.fromJson(<String, dynamic>{
        'enabled': true,
        'scope': 'bogus',
        'trustedSSIDs': <String>[],
      });
      expect(cfg.scope, OnDemandScope.all);
    });

    test('fromJson 缺字段回退缺省', () {
      final OnDemandConfig cfg = OnDemandConfig.fromJson(<String, dynamic>{});
      expect(cfg, const OnDemandConfig.defaults());
    });

    test('copyWith 仅改指定字段', () {
      const OnDemandConfig base = OnDemandConfig.defaults();
      final OnDemandConfig c = base.copyWith(
        enabled: true,
        trustedSSIDs: <String>['X'],
      );
      expect(c.enabled, isTrue);
      expect(c.scope, OnDemandScope.all); // 未指定，保持
      expect(c.trustedSSIDs, <String>['X']);
    });

    test('值相等：字段相同则相等、列表内容参与比较', () {
      const OnDemandConfig a = OnDemandConfig(
        enabled: true,
        scope: OnDemandScope.all,
        trustedSSIDs: <String>['A', 'B'],
      );
      const OnDemandConfig b = OnDemandConfig(
        enabled: true,
        scope: OnDemandScope.all,
        trustedSSIDs: <String>['A', 'B'],
      );
      const OnDemandConfig c = OnDemandConfig(
        enabled: true,
        scope: OnDemandScope.all,
        trustedSSIDs: <String>['A'],
      );
      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
