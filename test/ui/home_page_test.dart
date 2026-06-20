import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/config/subscriptions_store.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/home_page.dart';

/// 记录 start 入参的假 controller。
class _RecordingController implements CoreController {
  String? startedConfig;
  @override
  CoreState get state => CoreState.stopped;
  @override
  ControllerEndpoint? get currentEndpoint => null;
  @override
  Stream<CoreState> get stateStream => const Stream<CoreState>.empty();
  @override
  Future<void> start({required String configYAML}) async {
    startedConfig = configYAML;
  }

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

  Future<SubscriptionInfo> okFetcher(String url) async =>
      const SubscriptionInfo(
        ok: true,
        content: 'proxies:\n  - name: x\n',
        total: 100,
      );

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

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tmp = await Directory.systemTemp.createTemp('home_page_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  testWidgets('无当前订阅：连接按钮禁用 + 提示去订阅页', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    final RunParamsStore rp = RunParamsStore();
    await tester.runAsync(() async {
      await store.load();
      await rp.load();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          controller: _RecordingController(),
          store: store,
          runParams: rp,
        ),
      ),
    );
    await tester.pump();

    final Finder btn = find.widgetWithText(FilledButton, '连接');
    expect(btn, findsOneWidget);
    expect(tester.widget<FilledButton>(btn).onPressed, isNull);
    expect(find.textContaining('订阅页'), findsOneWidget);
  });

  testWidgets('有当前订阅：连接用合并运行参数后的配置', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    final RunParamsStore rp = RunParamsStore();
    await tester.runAsync(() async {
      await store.load();
      await store.add('A', 'https://a.com');
      await rp.load();
      await rp.save(rp.params.copyWith(mode: 'global'));
    });
    final _RecordingController ctrl = _RecordingController();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(controller: ctrl, store: store, runParams: rp),
      ),
    );
    await tester.pump();

    final Finder btn = find.widgetWithText(FilledButton, '连接');
    expect(tester.widget<FilledButton>(btn).onPressed, isNotNull);
    await tester.tap(btn);
    await tester.pump();
    await settleIo(tester);
    expect(ctrl.startedConfig, contains('proxies')); // 保留订阅正文
    expect(ctrl.startedConfig, contains('global')); // 合并了运行模式偏好
  });

  testWidgets('连接页含运行模式', (WidgetTester tester) async {
    final SubscriptionsStore store = makeStore();
    final RunParamsStore rp = RunParamsStore();
    await tester.runAsync(() async {
      await store.load();
      await rp.load();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          controller: _RecordingController(),
          store: store,
          runParams: rp,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('运行模式'), findsOneWidget);
  });
}
