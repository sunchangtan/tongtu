import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/core/theme_controller.dart';
import 'package:tongtu/ui/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    themeController.value = ThemeMode.system; // 重置全局状态，避免测试间污染
  });

  testWidgets('渲染应用层分组与关于；内核相关项已移出设置页', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsOneWidget);
    // 内核相关已迁至内核设置页
    expect(find.text('内核版本'), findsNothing);
    expect(find.text('分流规则'), findsNothing);
    expect(find.text('查看订阅配置'), findsNothing);
  });

  testWidgets('切换主题即时生效并持久化', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
    expect(themeController.value, ThemeMode.system);

    await tester.tap(find.text('暗'));
    await tester.pumpAndSettle();
    expect(themeController.value, ThemeMode.dark);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('提供按需连接入口并可进入子页', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();
    expect(find.text('按需连接'), findsOneWidget);

    await tester.tap(find.text('按需连接'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
