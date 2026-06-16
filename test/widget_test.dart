import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/home_page.dart';

/// 测试用 CoreController 假实现（不触碰 Platform Channel）。
class _FakeController implements CoreController {
  final StreamController<CoreState> _ctrl = StreamController<CoreState>.broadcast();

  @override
  Stream<CoreState> get stateStream => _ctrl.stream;

  @override
  CoreState get state => CoreState.stopped;

  @override
  ControllerEndpoint? get currentEndpoint => null;

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

  testWidgets('主界面渲染订阅输入、连接控件与状态', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: _FakeController())),
    );
    await tester.pumpAndSettle();

    expect(find.text('订阅链接'), findsOneWidget);
    expect(find.text('获取配置'), findsOneWidget);
    expect(find.text('连接'), findsOneWidget);
    expect(find.text('断开'), findsOneWidget);
    expect(find.textContaining('未连接'), findsOneWidget);
  });
}
