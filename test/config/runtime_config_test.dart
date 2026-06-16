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
  });
}
