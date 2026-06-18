import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('渲染分组与关于信息', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: _FakeController())),
      ),
    );
    await tester.pump();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('内核版本'), findsOneWidget);
    expect(find.textContaining('v1.19.27'), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsOneWidget);
  });

  testWidgets('切换主题即时生效并持久化', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: _FakeController())),
      ),
    );
    await tester.pump();
    expect(themeController.value, ThemeMode.system);

    await tester.tap(find.text('暗'));
    await tester.pumpAndSettle();
    expect(themeController.value, ThemeMode.dark);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('提供按需连接入口并可进入子页', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: _FakeController())),
      ),
    );
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
}
