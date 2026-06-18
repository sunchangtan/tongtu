import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';

void main() {
  const ControllerEndpoint endpoint = ControllerEndpoint(
    host: '127.0.0.1',
    port: 34567,
    secret: 's3cr3t',
  );

  group('ClashApi', () {
    test('getProxyGroups 解析含候选的组并附带 Bearer 鉴权', () async {
      final MockClient client = MockClient((http.Request req) async {
        expect(req.headers['Authorization'], 'Bearer s3cr3t');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'proxies': <String, dynamic>{
              'PROXY': <String, dynamic>{
                'type': 'Selector',
                'now': 'A',
                'all': <String>['A', 'B'],
              },
              'DIRECT': <String, dynamic>{'type': 'Direct'},
            },
          }),
          200,
        );
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      final Map<String, ProxyGroup> groups = await api.getProxyGroups();
      expect(groups.containsKey('PROXY'), isTrue);
      expect(groups.containsKey('DIRECT'), isFalse);
      expect(groups['PROXY']!.now, 'A');
      expect(groups['PROXY']!.all, <String>['A', 'B']);
      api.dispose();
    });

    test('selectProxy 发出 PUT 与节点名', () async {
      String? putBody;
      final MockClient client = MockClient((http.Request req) async {
        putBody = req.body;
        return http.Response('', 204);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      await api.selectProxy('PROXY', 'B');
      expect((jsonDecode(putBody!) as Map<String, dynamic>)['name'], 'B');
      api.dispose();
    });

    test('getRules 解析生效规则（实证格式）并附 Bearer 鉴权', () async {
      final MockClient client = MockClient((http.Request req) async {
        expect(req.url.path, '/rules');
        expect(req.headers['Authorization'], 'Bearer s3cr3t');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'rules': <dynamic>[
              <String, dynamic>{
                'index': 0,
                'type': 'DOMAIN-SUFFIX',
                'payload': 'google.com',
                'proxy': 'PROXY',
                'size': -1,
              },
              <String, dynamic>{
                'index': 1,
                'type': 'MATCH',
                'payload': '',
                'proxy': 'DIRECT',
                'size': -1,
              },
            ],
          }),
          200,
        );
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      final List<RuleItem> rules = await api.getRules();
      expect(rules.length, 2);
      expect(rules[0].type, 'DOMAIN-SUFFIX');
      expect(rules[0].payload, 'google.com');
      expect(rules[0].proxy, 'PROXY');
      expect(rules[1].type, 'MATCH');
      api.dispose();
    });

    test('getRules 鉴权失败抛 ClashApiException', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('', 401),
      );
      final ClashApi api = ClashApi(endpoint, client: client);
      await expectLater(api.getRules(), throwsA(isA<ClashApiException>()));
      api.dispose();
    });

    test('testDelay 返回毫秒', () async {
      final MockClient client = MockClient((http.Request req) async {
        return http.Response(jsonEncode(<String, dynamic>{'delay': 123}), 200);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      expect(await api.testDelay('A'), 123);
      api.dispose();
    });

    test('getConfigs 解析内核运行配置（实证格式）并附 Bearer', () async {
      final MockClient client = MockClient((http.Request req) async {
        expect(req.url.path, '/configs');
        expect(req.method, 'GET');
        expect(req.headers['Authorization'], 'Bearer s3cr3t');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'mode': 'global',
            'log-level': 'debug',
            'ipv6': true,
            'unified-delay': false,
            'sniffing': false,
          }),
          200,
        );
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      final KernelConfig cfg = await api.getConfigs();
      expect(cfg.mode, 'global');
      expect(cfg.logLevel, 'debug');
      expect(cfg.ipv6, isTrue);
      expect(cfg.unifiedDelay, isFalse);
      api.dispose();
    });

    test('patchConfigs 发 PATCH 仅改动字段（204 不抛）', () async {
      String? method;
      String? body;
      final MockClient client = MockClient((http.Request req) async {
        method = req.method;
        body = req.body;
        expect(req.url.path, '/configs');
        expect(req.headers['Authorization'], 'Bearer s3cr3t');
        return http.Response('', 204);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      await api.patchConfigs(<String, dynamic>{'mode': 'direct'});
      expect(method, 'PATCH');
      expect((jsonDecode(body!) as Map<String, dynamic>)['mode'], 'direct');
      api.dispose();
    });

    test('updateGeo 发 POST /configs/geo', () async {
      String? method;
      final MockClient client = MockClient((http.Request req) async {
        method = req.method;
        expect(req.url.path, '/configs/geo');
        return http.Response('', 204);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      await api.updateGeo();
      expect(method, 'POST');
      api.dispose();
    });

    test('flushFakeIP / flushDNS 发 POST /cache/*/flush', () async {
      final List<String> paths = <String>[];
      final MockClient client = MockClient((http.Request req) async {
        paths.add(req.url.path);
        expect(req.method, 'POST');
        return http.Response('', 204);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      await api.flushFakeIP();
      await api.flushDNS();
      expect(paths, <String>['/cache/fakeip/flush', '/cache/dns/flush']);
      api.dispose();
    });

    test('patchConfigs 失败抛 ClashApiException', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('', 400),
      );
      final ClashApi api = ClashApi(endpoint, client: client);
      await expectLater(
        api.patchConfigs(<String, dynamic>{'mode': 'rule'}),
        throwsA(isA<ClashApiException>()),
      );
      api.dispose();
    });

    test('updateGeo / flush 失败抛 ClashApiException', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('', 500),
      );
      final ClashApi api = ClashApi(endpoint, client: client);
      await expectLater(api.updateGeo(), throwsA(isA<ClashApiException>()));
      await expectLater(api.flushFakeIP(), throwsA(isA<ClashApiException>()));
      await expectLater(api.flushDNS(), throwsA(isA<ClashApiException>()));
      api.dispose();
    });

    test('getConfigs 缺字段用默认值、bool 字段异常类型不抛', () async {
      final MockClient client = MockClient(
        // 仅给异常类型 ipv6（数字），其余字段缺失
        (http.Request req) async =>
            http.Response(jsonEncode(<String, dynamic>{'ipv6': 1}), 200),
      );
      final ClashApi api = ClashApi(endpoint, client: client);
      final KernelConfig cfg = await api.getConfigs();
      expect(cfg.mode, 'rule'); // 缺字段默认
      expect(cfg.logLevel, 'info');
      expect(cfg.ipv6, isFalse); // 数字 1 宽松判定为 false，不抛 TypeError
      expect(cfg.unifiedDelay, isFalse);
      api.dispose();
    });

    test('鉴权失败抛 ClashApiException', () async {
      final MockClient client = MockClient((http.Request req) async {
        return http.Response('', 401);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      await expectLater(
        () => api.getProxyGroups(),
        throwsA(isA<ClashApiException>()),
      );
      api.dispose();
    });

    test('Traffic / LogEntry / ConnectionItem 解析', () {
      expect(
        Traffic.fromJson(<String, dynamic>{'up': 100, 'down': 200}).up,
        100,
      );
      expect(
        LogEntry.fromJson(<String, dynamic>{
          'type': 'info',
          'payload': 'hi',
        }).payload,
        'hi',
      );
      final ConnectionItem conn = ConnectionItem.fromJson(<String, dynamic>{
        'metadata': <String, dynamic>{'host': 'example.com'},
        'chains': <String>['PROXY', 'A'],
        'rule': 'Match',
        'upload': 10,
        'download': 20,
      });
      expect(conn.host, 'example.com');
      expect(conn.chains, <String>['PROXY', 'A']);
    });

    test('LogEntry 记录接收时间戳', () {
      final DateTime before = DateTime.now();
      final LogEntry e = LogEntry.fromJson(<String, dynamic>{
        'type': 'warning',
        'payload': 'x',
      });
      // mihomo /logs 不带时间，时间戳取接收时刻，应 >= 调用前
      expect(e.time.isBefore(before), isFalse);
      expect(e.type, 'warning');
    });
  });
}
