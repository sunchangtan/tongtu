import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/monitor_page.dart';

class _FakeController implements CoreController {
  _FakeController({required this.state});

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
  testWidgets('监控页未连接显示空态', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitorPage(
            controller: _FakeController(state: CoreState.stopped),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('请先'), findsOneWidget);
  });
}
