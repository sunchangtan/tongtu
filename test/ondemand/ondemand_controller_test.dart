import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ondemand/ondemand_config.dart';
import 'package:tongtu/ondemand/ondemand_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('test/ondemand');

  void mock(Future<Object?>? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  group('OnDemandController', () {
    test('update 发送 updateOnDemand 与完整参数', () async {
      MethodCall? captured;
      mock((MethodCall call) async {
        captured = call;
        return null;
      });
      final OnDemandController c = OnDemandController(channel: channel);
      await c.update(
        const OnDemandConfig(
          enabled: true,
          scope: OnDemandScope.wifiOnly,
          trustedSSIDs: <String>['Home'],
        ),
      );
      expect(captured?.method, 'updateOnDemand');
      final Map<Object?, Object?> args =
          captured?.arguments as Map<Object?, Object?>;
      expect(args['enabled'], true);
      expect(args['scope'], 'wifiOnly');
      expect(args['trustedSSIDs'], <String>['Home']);
    });

    test('currentSSID 成功返回 SSID', () async {
      mock((MethodCall call) async => 'MyWiFi');
      final OnDemandController c = OnDemandController(channel: channel);
      expect(await c.currentSSID(), 'MyWiFi');
    });

    test('currentSSID 权限被拒抛 PlatformException(denied)', () async {
      mock((MethodCall call) async {
        throw PlatformException(code: 'denied');
      });
      final OnDemandController c = OnDemandController(channel: channel);
      await expectLater(
        c.currentSSID(),
        throwsA(
          isA<PlatformException>().having(
            (PlatformException e) => e.code,
            'code',
            'denied',
          ),
        ),
      );
    });
  });
}
