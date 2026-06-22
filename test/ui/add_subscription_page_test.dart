import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/config/subscriptions_store.dart';
import 'package:tongtu/ui/add_subscription_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int idCounter;

  Future<SubscriptionInfo> okFetcher(String url, String? ua) async =>
      const SubscriptionInfo(ok: true, content: 'proxies:\n  - name: x\n');

  SubscriptionsStore makeStore() {
    idCounter = 0;
    return SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'id${++idCounter}',
      fetcher: okFetcher,
    );
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(
    WidgetTester tester,
    SubscriptionsStore store, {
    Future<String?> Function()? clipboardReader,
    Future<String?> Function(BuildContext)? scanner,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddSubscriptionPage(
          store: store,
          clipboardReader: clipboardReader,
          scanner: scanner,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tmp = await Directory.systemTemp.createTemp('add_sub_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  testWidgets('空输入：添加按钮禁用', (WidgetTester tester) async {
    await pumpPage(tester, makeStore());
    final Finder btn = find.widgetWithText(FilledButton, '添加');
    expect(tester.widget<FilledButton>(btn).onPressed, isNull);
  });

  testWidgets('从剪贴板导入填入输入框', (WidgetTester tester) async {
    await pumpPage(
      tester,
      makeStore(),
      clipboardReader: () async => 'https://clip.example/sub',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '从剪贴板'));
    await tester.pump();
    expect(find.text('https://clip.example/sub'), findsOneWidget);
  });

  testWidgets('扫码结果填入输入框', (WidgetTester tester) async {
    await pumpPage(
      tester,
      makeStore(),
      scanner: (BuildContext _) async => 'https://scan.example/sub',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '扫码'));
    await tester.pump();
    expect(find.text('https://scan.example/sub'), findsOneWidget);
  });

  testWidgets('URL 输入 → add 入库', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() => store.load());
    await pumpPage(tester, store);
    // 名称(0) / 输入框(1) / UA(2)
    await tester.enterText(find.byType(TextField).at(1), 'https://a.com');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();
    await settleIo(tester);
    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.url, 'https://a.com');
  });

  testWidgets('直接内容输入 → addContent 入库（url 空）', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() => store.load());
    await pumpPage(tester, store);
    await tester.enterText(
      find.byType(TextField).at(1),
      'proxies:\n  - name: y\n',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();
    await settleIo(tester);
    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.url, ''); // 内容订阅无 url
  });
}
