import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:tongtu/config/subscriptions_store.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/core/theme_controller.dart';
import 'package:tongtu/ui/settings_page.dart';

class _FakeController implements CoreController {
  @override
  CoreState get state => CoreState.stopped;
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    themeController.value = ThemeMode.system; // 重置全局状态，避免测试间污染
  });

  Widget page() => MaterialApp(
    home: SettingsPage(
      controller: _FakeController(),
      runParams: RunParamsStore(),
      store: SubscriptionsStore(),
    ),
  );

  testWidgets('渲染应用层分组与关于；内核相关项已移出设置页主体', (WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsOneWidget);
    // 内核相关项在内核设置二级页，不在设置页主体
    expect(find.text('内核版本'), findsNothing);
    expect(find.text('分流规则'), findsNothing);
    expect(find.text('查看订阅配置'), findsNothing);
  });

  testWidgets('切换主题即时生效并持久化', (WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pump();
    expect(themeController.value, ThemeMode.system);

    await tester.tap(find.text('暗'));
    await tester.pumpAndSettle();
    expect(themeController.value, ThemeMode.dark);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('提供按需连接入口并可进入子页', (WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('按需连接'), findsOneWidget);

    await tester.tap(find.text('按需连接'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('提供内核设置入口并可进入二级页', (WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pump();
    expect(find.text('内核设置'), findsOneWidget);

    await tester.tap(find.text('内核设置'));
    await tester.pumpAndSettle();
    // 进入内核设置二级页：AppBar 标题 + 运行参数组可见
    expect(find.widgetWithText(AppBar, '内核设置'), findsOneWidget);
    expect(find.text('运行参数'), findsOneWidget);
  });
}
