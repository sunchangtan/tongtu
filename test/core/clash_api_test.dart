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

    test('testDelay 返回毫秒', () async {
      final MockClient client = MockClient((http.Request req) async {
        return http.Response(jsonEncode(<String, dynamic>{'delay': 123}), 200);
      });
      final ClashApi api = ClashApi(endpoint, client: client);
      expect(await api.testDelay('A'), 123);
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
  });
}
