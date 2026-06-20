import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/home_shell.dart';

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

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('底部三层导航：连接 / 订阅 / 设置', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(controller: _FakeController())),
    );
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('连接'), findsWidgets);
    expect(find.text('订阅'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    // 内核设置不再是底部 tab（降为设置二级入口）
    expect(find.widgetWithText(NavigationDestination, '内核设置'), findsNothing);
  });

  testWidgets('切到订阅 tab 可达', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(controller: _FakeController())),
    );
    await tester.pump();
    await tester.tap(find.text('订阅'));
    await tester.pumpAndSettle();
    // 订阅页空态提示可见
    expect(find.textContaining('还没有订阅'), findsOneWidget);
  });

  testWidgets('切到设置 tab 可达', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(controller: _FakeController())),
    );
    await tester.pump();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('内核设置'), findsOneWidget); // 设置页内的二级入口
  });
}
