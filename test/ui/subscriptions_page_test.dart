import 'dart:io';
import 'package:tongtu/ui/icons/tongtu_icons.g.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/config/subscriptions_store.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/subscriptions_page.dart';

/// 可配置连接态的假 controller（订阅页仅用 state 判断是否提示重连）。
class _FakeController implements CoreController {
  _FakeController({this.state = CoreState.stopped});
  @override
  final CoreState state;
  @override
  ControllerEndpoint? get currentEndpoint => null;
  @override
  Stream<CoreState> get stateStream => const Stream<CoreState>.empty();
  @override
  Future<void> start({required String configYAML}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<MemorySnapshot?> memorySnapshot() async => null;
  @override
  Future<String> lastResult() async => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int idCounter;

  Future<SubscriptionInfo> okFetcher(String url, String? ua) async =>
      const SubscriptionInfo(
        ok: true,
        content: 'proxies:\n  - name: x\n',
        total: 100,
        download: 30,
      );

  SubscriptionsStore makeStore({
    Future<SubscriptionInfo> Function(String, String?)? fetcher,
  }) {
    idCounter = 0;
    return SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'id${++idCounter}',
      fetcher: fetcher ?? okFetcher,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    SubscriptionsStore store, {
    CoreState state = CoreState.stopped,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionsPage(
          store: store,
          controller: _FakeController(state: state),
        ),
      ),
    );
    await tester.pump();
  }

  // 让点击触发的链式真实文件 IO（建目录→写盘→持久化）跑完：
  // runAsync 跑物理 IO ↔ pump 跑续延（派发下一步 IO），交替排空整条链，再 pumpAndSettle。
  Future<void> settleIo(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tmp = await Directory.systemTemp.createTemp('subs_page_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  testWidgets('列表渲染：两条订阅 + 当前标记', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() async {
      await store.load();
      await store.add('订阅A', 'https://a.com');
      await store.add('订阅B', 'https://b.com');
    });
    await pumpPage(tester, store);

    expect(find.text('订阅A'), findsOneWidget);
    expect(find.text('订阅B'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget); // 仅首条为当前
  });

  testWidgets('空态：提示去添加', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() => store.load());
    await pumpPage(tester, store);

    expect(find.textContaining('还没有订阅'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('点 FAB 打开添加订阅页', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() => store.load());
    await pumpPage(tester, store);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '添加订阅'), findsOneWidget);
  });

  testWidgets('切换当前：点非当前卡', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() async {
      await store.load();
      await store.add('订阅A', 'https://a.com'); // id1 当前
      await store.add('订阅B', 'https://b.com'); // id2
    });
    await pumpPage(tester, store);

    await tester.tap(find.text('订阅B'));
    await tester.pumpAndSettle();
    expect(store.currentId, 'id2');
    expect(find.text('当前'), findsOneWidget); // 仍只有一个当前标记
  });

  testWidgets('已连接切换：提示重连', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() async {
      await store.load();
      await store.add('订阅A', 'https://a.com');
      await store.add('订阅B', 'https://b.com');
    });
    await pumpPage(tester, store, state: CoreState.connected);

    await tester.tap(find.text('订阅B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750)); // 让 SnackBar 出现
    expect(find.textContaining('重连'), findsOneWidget);
  });

  testWidgets('删除当前：转移到首项 + 移除卡', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    await tester.runAsync(() async {
      await store.load();
      await store.add('订阅A', 'https://a.com'); // id1 当前
      await store.add('订阅B', 'https://b.com'); // id2
    });
    await pumpPage(tester, store);

    // 首卡（订阅A=当前）的删除按钮
    await tester.tap(find.byIcon(TongtuIcons.trash2).first);
    await tester.pumpAndSettle(); // 确认弹窗
    await tester.tap(find.text('删除'));
    await tester.pump();
    await settleIo(tester);

    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.id, 'id2');
    expect(store.currentId, 'id2');
    expect(find.text('订阅A'), findsNothing);
  });

  testWidgets('更新：重拉刷新 info', (WidgetTester tester) async {
    int calls = 0;
    final SubscriptionsStore store = makeStore(
      fetcher: (String url, String? ua) async {
        calls++;
        return SubscriptionInfo(
          ok: true,
          content: 'proxies:\n  - name: x\n',
          total: calls * 100,
        );
      },
    );
    await tester.runAsync(() async {
      await store.load();
      await store.add('订阅A', 'https://a.com'); // calls=1, total=100
    });
    await pumpPage(tester, store);

    await tester.tap(find.byIcon(TongtuIcons.refreshCw));
    await tester.pump();
    await settleIo(tester);

    expect(store.subscriptions.first.info?.total, 200); // calls=2
  });
}
