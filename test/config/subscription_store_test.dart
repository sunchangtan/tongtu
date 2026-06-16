import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('保存并读取有效订阅链接', () async {
      final SubscriptionStore store = SubscriptionStore();
      await store.save('https://example.com/sub');
      expect(await store.load(), 'https://example.com/sub');
    });

    test('无效链接抛中文 FormatException', () async {
      final SubscriptionStore store = SubscriptionStore();
      await expectLater(
        () => store.save('not-a-url'),
        throwsA(isA<FormatException>()),
      );
    });

    test('获取配置：解析 subscription-userinfo 流量/到期', () async {
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          'proxies: []',
          200,
          headers: <String, String>{
            'subscription-userinfo':
                'upload=100; download=200; total=1000; expire=1700000000',
          },
        );
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isTrue);
      expect(info.total, 1000);
      expect(info.download, 200);
      expect(info.expire, 1700000000);
    });

    test('获取配置：HTTP 错误返回 ok=false', () async {
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('', 404);
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isFalse);
    });

    test('获取配置：无效链接返回 ok=false', () async {
      final SubscriptionStore store = SubscriptionStore();
      final SubscriptionInfo info = await store.fetch('not-a-url');
      expect(info.ok, isFalse);
    });
  });
}
