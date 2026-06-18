import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/ondemand/ondemand_config.dart';
import 'package:tongtu/ondemand/ondemand_controller.dart';
import 'package:tongtu/ondemand/ondemand_store.dart';
import 'package:tongtu/ui/ondemand_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('test/ondemand_page');

  late List<MethodCall> calls;
  String? ssidResult;
  PlatformException? ssidError;

  setUp(() {
    calls = <MethodCall>[];
    ssidResult = null;
    ssidError = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          if (call.method == 'currentSSID') {
            if (ssidError != null) {
              throw ssidError!;
            }
            return ssidResult;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnDemandPage(
            store: OnDemandStore(),
            controller: OnDemandController(channel: channel),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('初始渲染总开关（默认关闭）', (WidgetTester tester) async {
    await pumpPage(tester);
    expect(find.byType(SwitchListTile), findsOneWidget);
    final SwitchListTile sw = tester.widget(find.byType(SwitchListTile));
    expect(sw.value, isFalse);
  });

  testWidgets('关闭总开关时触发范围禁用', (WidgetTester tester) async {
    await pumpPage(tester);
    final SegmentedButton<OnDemandScope> seg = tester.widget(
      find.byType(SegmentedButton<OnDemandScope>),
    );
    expect(seg.onSelectionChanged, isNull);
  });

  testWidgets('开启总开关下发 updateOnDemand(enabled=true)', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final MethodCall last = calls.lastWhere(
      (MethodCall c) => c.method == 'updateOnDemand',
    );
    expect((last.arguments as Map<Object?, Object?>)['enabled'], true);
  });

  testWidgets('添加当前 Wi-Fi 成功加入信任列表', (WidgetTester tester) async {
    ssidResult = 'Home-5G';
    await pumpPage(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加当前 Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Home-5G'), findsOneWidget);
  });

  testWidgets('添加当前 Wi-Fi 被拒显示权限提示', (WidgetTester tester) async {
    ssidError = PlatformException(code: 'denied');
    await pumpPage(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加当前 Wi-Fi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('权限'), findsOneWidget);
  });
}
