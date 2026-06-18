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

  testWidgets('底部三层导航：连接 / 设置 / 内核设置', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(controller: _FakeController())),
    );
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    // 设置 / 内核设置为唯一文案，验证底部 tab 存在
    expect(find.text('设置'), findsWidgets);
    expect(find.text('内核设置'), findsWidgets);
  });

  testWidgets('切到内核设置 tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(controller: _FakeController())),
    );
    await tester.pump();
    await tester.tap(find.text('内核设置'));
    await tester.pumpAndSettle();
    // 切换成功：内核设置页内容（运行参数组）可见（页面已无 AppBar 标题）
    expect(find.text('运行参数'), findsOneWidget);
  });
}
