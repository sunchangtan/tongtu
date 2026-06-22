import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/config_viewer_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('展示当前订阅配置原文', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigViewerPage(
          loader: () async => 'proxies:\n  - test-node-X\n',
        ),
      ),
    );
    await tester.pump(); // 让 loader 解析、_loading=false
    await tester.pump();
    expect(find.textContaining('test-node-X'), findsOneWidget);
  });

  testWidgets('无配置显示空态', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ConfigViewerPage(loader: () async => null)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('尚无配置'), findsOneWidget);
  });
}
