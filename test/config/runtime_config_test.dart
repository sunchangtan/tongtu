import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/config/runtime_config.dart';

void main() {
  group('RuntimeConfig', () {
    test('生成的 YAML 含订阅 proxy-providers 与推荐项', () {
      final String yaml = RuntimeConfig.generateYAML(
        subscriptionUrl: 'https://example.com/sub',
      );
      expect(yaml, contains('proxy-providers'));
      expect(yaml, contains('https://example.com/sub'));
      expect(yaml, contains('fake-ip'));
      expect(yaml, contains('MATCH,PROXY'));
    });

    test('端口在 20000-59999 范围', () {
      final int port = RuntimeConfig.generatePort(Random(42));
      expect(port, greaterThanOrEqualTo(20000));
      expect(port, lessThan(60000));
    });

    test('secret 为 32 位十六进制', () {
      final String secret = RuntimeConfig.generateSecret(Random(42));
      expect(secret, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(secret), isTrue);
    });
  });
}
