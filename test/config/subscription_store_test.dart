import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tongtu/config/subscription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionStore.fetch', () {
    test('解析 subscription-userinfo 流量/到期 + 保留完整正文', () async {
      final SubscriptionStore store = SubscriptionStore();
      const String body =
          'proxies:\n  - {name: a, type: socks5, server: 1.1.1.1, port: 1080}\n';
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          body,
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
      expect(info.content, body); // copyWith 保留完整正文
    });

    test('HTTP 错误返回 ok=false', () async {
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

    test('无效链接返回 ok=false', () async {
      final SubscriptionStore store = SubscriptionStore();
      final SubscriptionInfo info = await store.fetch('not-a-url');
      expect(info.ok, isFalse);
    });

    test('非合法 clash 配置（无顶层 proxies/proxy-providers）ok=false', () async {
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('<html>error page</html>', 200);
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isFalse);
      expect(info.content, isNull);
    });

    test('proxies 仅出现在非行首（注释/字符串）不误判为合法', () async {
      // 真 YAML 解析：含字样但非顶层 key → 仍判非法（杜绝子串 contains 误判）
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          '# this config has no proxies yet\n{"error":"too many proxies"}',
          200,
        );
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isFalse);
    });

    test('proxies 为空列表 → 判非法（真 YAML 识别空节点，正则做不到）', () async {
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('proxies: []', 200);
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isFalse);
    });

    test('含非空 proxy-providers → 合法', () async {
      final SubscriptionStore store = SubscriptionStore();
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          'proxy-providers:\n  sub:\n    type: http\n    url: "http://x/y"\n',
          200,
        );
      });
      final SubscriptionInfo info = await store.fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(info.ok, isTrue);
    });

    test('自定义 userAgent 发出对应 UA 头', () async {
      String? sentUa;
      final MockClient client = MockClient((http.Request req) async {
        sentUa = req.headers['User-Agent'] ?? req.headers['user-agent'];
        return http.Response('proxies:\n  - name: x\n', 200);
      });
      await SubscriptionStore().fetch(
        'https://example.com/sub',
        client: client,
        userAgent: 'tongtu/1.0',
      );
      expect(sentUa, 'tongtu/1.0');
    });

    test('默认 UA = clash.meta', () async {
      String? sentUa;
      final MockClient client = MockClient((http.Request req) async {
        sentUa = req.headers['User-Agent'] ?? req.headers['user-agent'];
        return http.Response('proxies:\n  - name: x\n', 200);
      });
      await SubscriptionStore().fetch(
        'https://example.com/sub',
        client: client,
      );
      expect(sentUa, 'clash.meta');
    });
  });

  group('SubscriptionStore.validateContent', () {
    test('合法内容返回 ok + content', () {
      final SubscriptionInfo info = SubscriptionStore.validateContent(
        'proxies:\n  - name: x\n',
      );
      expect(info.ok, isTrue);
      expect(info.content, contains('proxies'));
    });

    test('非法内容返回 ok=false', () {
      final SubscriptionInfo info = SubscriptionStore.validateContent(
        '<html>nope</html>',
      );
      expect(info.ok, isFalse);
    });
  });
}
