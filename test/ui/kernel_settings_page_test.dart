import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:tongtu/config/subscriptions_store.dart';
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

// 大 viewport：避免 ListView 懒加载导致底部项未构建。
Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: page));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('二级页：有 AppBar 标题「内核设置」', (WidgetTester tester) async {
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(),
        runParams: rp,
        store: SubscriptionsStore(),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(AppBar, '内核设置'), findsOneWidget);
  });

  testWidgets('未连接：运行参数常亮可改 + 重连提示；维护灰置', (WidgetTester tester) async {
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(),
        runParams: rp,
        store: SubscriptionsStore(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('重连生效'), findsOneWidget); // 提示
    expect(find.text('日志级别'), findsOneWidget);
    expect(find.text('IPv6'), findsOneWidget);
    expect(find.text('统一延迟'), findsOneWidget);
    expect(find.text('TCP 并发'), findsOneWidget);
    expect(find.text('域名嗅探'), findsOneWidget);
    expect(find.text('运行模式'), findsNothing); // 在连接首页

    // 未连接也能改（store 驱动）：切 IPv6
    await tester.tap(find.widgetWithText(SwitchListTile, 'IPv6'));
    await tester.pump();
    expect(rp.params.ipv6, isTrue);

    // 维护动作未连接灰置
    final ListTile geo = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '更新 GEO 数据库'),
    );
    expect(geo.enabled, isFalse);
  });

  testWidgets('改 TCP 并发与局域网接入存为偏好', (WidgetTester tester) async {
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(),
        runParams: rp,
        store: SubscriptionsStore(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(SwitchListTile, 'TCP 并发'));
    await tester.pump();
    expect(rp.params.tcpConcurrent, isFalse); // 默认 true → 切为 false

    await tester.tap(find.widgetWithText(SwitchListTile, '局域网接入'));
    await tester.pump();
    expect(rp.params.allowLan, isTrue);
  });

  testWidgets('连接中：更新 GEO 发 POST /configs/geo', (WidgetTester tester) async {
    String? postPath;
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/configs/geo') {
        postPath = req.url.path;
        return http.Response('', 204);
      }
      return http.Response('', 404);
    });
    final RunParamsStore rp = RunParamsStore();
    await rp.load();
    await _pump(
      tester,
      KernelSettingsPage(
        controller: _FakeController(
          state: CoreState.connected,
          currentEndpoint: _ep,
        ),
        runParams: rp,
        store: SubscriptionsStore(),
        apiFactory: (ControllerEndpoint ep) => ClashApi(ep, client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新 GEO 数据库'));
    await tester.pumpAndSettle();
    expect(postPath, '/configs/geo');
  });
}
