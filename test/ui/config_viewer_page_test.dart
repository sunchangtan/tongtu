import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/ui/config_viewer_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('展示订阅配置原文', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Directory tmp = Directory.systemTemp.createTempSync('cfg');
    final SubscriptionStore store = SubscriptionStore(
      configDir: () async => tmp,
    );
    await tester.runAsync(() async {
      await store.saveContent('proxies:\n  - test-node-X\n', 'https://x');
      await tester.pumpWidget(
        MaterialApp(home: ConfigViewerPage(store: store)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining('test-node-X'), findsOneWidget);

    tmp.deleteSync(recursive: true);
  });

  testWidgets('未获取配置显示空态', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Directory tmp = Directory.systemTemp.createTempSync('cfg2');
    final SubscriptionStore store = SubscriptionStore(
      configDir: () async => tmp,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: ConfigViewerPage(store: store)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining('尚未获取'), findsOneWidget);

    tmp.deleteSync(recursive: true);
  });
}
