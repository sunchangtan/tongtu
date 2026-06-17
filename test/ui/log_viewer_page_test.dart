import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/log_viewer_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('com.dingqi.tongtu/core');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('回看页显示全量日志并支持关键词搜索', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('logviewer_test');
    File('${dir.path}/core.log').writeAsStringSync('line-AAA\nline-BBB\n');
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      return call.method == 'logDir' ? dir.path : null;
    });

    // _load 读真实文件 IO，需 runAsync 跑真实 async；再 pump 刷新（不用 pumpAndSettle，
    // 因 loading 期间 LinearProgressIndicator 无限动画会让 pumpAndSettle 永不收敛）
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 回看显示全量
    expect(find.textContaining('line-AAA'), findsOneWidget);
    expect(find.textContaining('line-BBB'), findsOneWidget);

    // 搜索 AAA → 只剩匹配行
    await tester.enterText(find.byType(TextField), 'AAA');
    await tester.pump();
    expect(find.textContaining('line-AAA'), findsOneWidget);
    expect(find.textContaining('line-BBB'), findsNothing);

    messenger.setMockMethodCallHandler(channel, null);
    dir.deleteSync(recursive: true);
  });
}
