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

  testWidgets('回看页清空：确认后删除落盘文件并重载为空', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync(
      'logviewer_clear',
    );
    File('${dir.path}/core.log').writeAsStringSync('line-CCC\n');
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      return call.method == 'logDir' ? dir.path : null;
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining('line-CCC'), findsOneWidget);

    // 点「清空」→ 弹确认框，先取消：文件与显示都不变
    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.textContaining('line-CCC'), findsOneWidget);
    expect(File('${dir.path}/core.log').existsSync(), isTrue);

    // 再点「清空」→ 确认：删除文件并重载为空
    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();
    // 确认点击放在 runAsync 外：手势需 pump 帧解析才会触发 onPressed → _clear()
    await tester.tap(find.widgetWithText(TextButton, '清空'));
    // _clear 内 await 真实文件删除/重读，用 runAsync 放行其延续完成
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('line-CCC'), findsNothing);
    expect(File('${dir.path}/core.log').existsSync(), isFalse);

    messenger.setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
}
