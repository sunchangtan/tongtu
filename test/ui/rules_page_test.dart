import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/rules_page.dart';

class _FakeController implements CoreController {
  _FakeController(this._state, this._endpoint);
  final CoreState _state;
  final ControllerEndpoint? _endpoint;

  @override
  CoreState get state => _state;
  @override
  ControllerEndpoint? get currentEndpoint => _endpoint;
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
        home: RulesPage(controller: _FakeController(CoreState.stopped, null)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('请先'), findsOneWidget);
  });

  testWidgets('连接后展示规则并支持搜索', (WidgetTester tester) async {
    const ControllerEndpoint endpoint = ControllerEndpoint(
      host: '127.0.0.1',
      port: 1,
      secret: 'x',
    );
    final MockClient client = MockClient((http.Request req) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'rules': <dynamic>[
            <String, dynamic>{
              'type': 'DOMAIN-SUFFIX',
              'payload': 'google.com',
              'proxy': 'PROXY',
            },
            <String, dynamic>{
              'type': 'MATCH',
              'payload': '',
              'proxy': 'DIRECT',
            },
          ],
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RulesPage(
          controller: _FakeController(CoreState.connected, endpoint),
          apiFactory: (ControllerEndpoint e) => ClashApi(e, client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('google.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'google');
    await tester.pump();
    expect(find.textContaining('google.com'), findsOneWidget);
    expect(find.textContaining('MATCH'), findsNothing);
  });
}
