import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/kernel_settings_page.dart';

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

// 大 viewport：避免 ListView 懒加载导致底部项（内核信息）未构建。
Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: page));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('未连接：运行参数灰置并提示「连接后可调」', (WidgetTester tester) async {
    await _pump(tester, KernelSettingsPage(controller: _FakeController()));
    await tester.pump();
    expect(find.text('连接后可调'), findsOneWidget);
    expect(find.text('运行模式'), findsOneWidget);
    expect(find.text('内核版本'), findsOneWidget); // 不依赖连接
    expect(find.text('unified-delay'), findsNothing); // 仅连接中只读展示
  });

  testWidgets('连接中：getConfigs 回填 + 改运行模式发 PATCH', (WidgetTester tester) async {
    String? patchBody;
    final MockClient client = MockClient((http.Request req) async {
      if (req.method == 'GET' && req.url.path == '/configs') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'mode': 'rule',
            'log-level': 'info',
            'ipv6': false,
            'unified-delay': true,
          }),
          200,
        );
      }
      if (req.method == 'PATCH') {
        patchBody = req.body;
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(
          state: CoreState.connected,
          currentEndpoint: _ep,
        ),
        apiFactory: (ControllerEndpoint ep) => ClashApi(ep, client: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('unified-delay'), findsOneWidget); // 回填后展示
    await tester.tap(find.text('全局'));
    await tester.pumpAndSettle();
    expect((jsonDecode(patchBody!) as Map<String, dynamic>)['mode'], 'global');
  });

  testWidgets('连接中：更新 GEO 发 POST /configs/geo', (WidgetTester tester) async {
    String? postPath;
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/configs') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'mode': 'rule',
            'log-level': 'info',
            'ipv6': false,
            'unified-delay': false,
          }),
          200,
        );
      }
      if (req.url.path == '/configs/geo') {
        postPath = req.url.path;
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(
          state: CoreState.connected,
          currentEndpoint: _ep,
        ),
        apiFactory: (ControllerEndpoint ep) => ClashApi(ep, client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新 GEO 数据库'));
    await tester.pumpAndSettle();
    expect(postPath, '/configs/geo');
  });

  testWidgets('内核返回未知 log-level 不崩溃（回退默认）', (WidgetTester tester) async {
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/configs') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'mode': 'rule',
            'log-level': 'verbose', // 不在固定 5 项内
            'ipv6': false,
            'unified-delay': false,
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(
          state: CoreState.connected,
          currentEndpoint: _ep,
        ),
        apiFactory: (ControllerEndpoint ep) => ClashApi(ep, client: client),
      ),
    );
    await tester.pumpAndSettle();
    // 未触发 DropdownButton「value 必须在 items 中」断言、页面正常渲染
    expect(find.text('运行模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
