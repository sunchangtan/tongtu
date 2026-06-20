import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/run_mode_selector.dart';

class _FakeController implements CoreController {
  _FakeController({this.state = CoreState.stopped, this.currentEndpoint});
  @override
  final CoreState state;
  @override
  final ControllerEndpoint? currentEndpoint;
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

const ControllerEndpoint _ep = ControllerEndpoint(
  host: '127.0.0.1',
  port: 9090,
  secret: 's',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('未连接：常亮可改 mode 并存为偏好', (WidgetTester tester) async {
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      RunModeSelector(controller: _FakeController(), runParams: rp),
    );
    await tester.pump();

    final SegmentedButton<String> sb = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(sb.onSelectionChanged, isNotNull); // 未连接也可改（不灰置）

    await tester.tap(find.text('全局'));
    await tester.pump();
    expect(rp.params.mode, 'global'); // 存为偏好
  });

  testWidgets('回填显示当前偏好', (WidgetTester tester) async {
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await rp.save(rp.params.copyWith(mode: 'direct'));
    await _pump(
      tester,
      RunModeSelector(controller: _FakeController(), runParams: rp),
    );
    await tester.pump();
    final SegmentedButton<String> sb = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(sb.selected, <String>{'direct'});
  });

  testWidgets('连接中改 mode：存偏好 + 发 PATCH 热切', (WidgetTester tester) async {
    String? patchBody;
    final MockClient client = MockClient((http.Request req) async {
      if (req.method == 'PATCH') {
        patchBody = req.body;
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      RunModeSelector(
        controller: _FakeController(
          state: CoreState.connected,
          currentEndpoint: _ep,
        ),
        runParams: rp,
        apiFactory: (ControllerEndpoint ep) => ClashApi(ep, client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全局'));
    await tester.pumpAndSettle();
    expect(rp.params.mode, 'global'); // 偏好
    expect((jsonDecode(patchBody!) as Map<String, dynamic>)['mode'], 'global');
  });
}
