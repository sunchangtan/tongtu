import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:tongtu/config/subscriptions_store.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/connect_shell.dart';

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

  testWidgets('连接首页含 连接/节点/监控 三子 tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectShell(
          controller: _FakeController(),
          store: SubscriptionsStore(),
          runParams: RunParamsStore(),
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(Tab, '连接'), findsOneWidget);
    expect(find.widgetWithText(Tab, '节点'), findsOneWidget);
    expect(find.widgetWithText(Tab, '监控'), findsOneWidget);
  });

  testWidgets('点节点 tab 可切到节点子页', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectShell(
          controller: _FakeController(),
          store: SubscriptionsStore(),
          runParams: RunParamsStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, '节点'));
    await tester.pumpAndSettle();
    // 切换不抛错即成功（节点子页未连接空态可达）
    expect(find.widgetWithText(Tab, '节点'), findsOneWidget);
  });
}
