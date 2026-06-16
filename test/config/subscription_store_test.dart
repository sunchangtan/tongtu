import 'package:flutter_test/flutter_test.dart';
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
  });
}
