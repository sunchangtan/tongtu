import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionStore', () {
    late Directory tmp;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tmp = Directory.systemTemp.createTempSync('sub_test');
    });

    tearDown(() {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    });

    // 注入临时目录作为配置正文落盘位置（生产用 path_provider）
    SubscriptionStore storeWithDir() =>
        SubscriptionStore(configDir: () async => tmp);

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

    test('获取配置：解析 subscription-userinfo 流量/到期 + 保留完整正文', () async {
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

    test('获取配置：非合法 clash 配置（无顶层 proxies/proxy-providers）ok=false', () async {
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

    test('获取配置：proxies 仅出现在非行首（注释/字符串）不误判为合法', () async {
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

    test('获取配置：proxies 为空列表 → 判非法（真 YAML 识别空节点，正则做不到）', () async {
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

    test('获取配置：含非空 proxy-providers → 合法', () async {
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

    test('保存并读取完整配置正文（落文件）+ 来源 url', () async {
      final SubscriptionStore store = storeWithDir();
      const String yaml = 'proxy-providers:\n  sub: {type: http}\n';
      await store.saveContent(yaml, 'https://example.com/sub');
      expect(await store.loadContent(), yaml);
      expect(await store.loadContentSourceUrl(), 'https://example.com/sub');
      expect(File('${tmp.path}/subscription.yaml').existsSync(), isTrue);
    });

    test('未保存时 loadContent 返回 null', () async {
      final SubscriptionStore store = storeWithDir();
      expect(await store.loadContent(), isNull);
    });
  });
}
