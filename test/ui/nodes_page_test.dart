import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/nodes_page.dart';

/// 可配状态/端点的测试用 CoreController。
class _FakeController implements CoreController {
  _FakeController({required this.state, this.currentEndpoint});

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

void main() {
  testWidgets('未连接显示空态', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NodesPage(
            controller: _FakeController(state: CoreState.stopped),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('请先'), findsOneWidget);
  });

  testWidgets('连接后展示节点组与候选', (WidgetTester tester) async {
    const ControllerEndpoint endpoint = ControllerEndpoint(
      host: '127.0.0.1',
      port: 34567,
      secret: 's',
    );
    final MockClient client = MockClient((http.Request req) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'proxies': <String, dynamic>{
            'PROXY': <String, dynamic>{
              'type': 'Selector',
              'now': 'A',
              'all': <String>['A', 'B'],
            },
          },
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NodesPage(
            controller: _FakeController(
              state: CoreState.connected,
              currentEndpoint: endpoint,
            ),
            apiFactory: (ControllerEndpoint e) => ClashApi(e, client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PROXY'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
