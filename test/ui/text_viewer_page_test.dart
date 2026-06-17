import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/text_viewer_page.dart';

void main() {
  testWidgets('加载文本并支持关键词搜索', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TextViewerPage(
          title: '文本',
          loader: () async => 'line-AAA\nline-BBB\n',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('line-AAA'), findsOneWidget);
    expect(find.textContaining('line-BBB'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'AAA');
    await tester.pump();
    expect(find.textContaining('line-AAA'), findsOneWidget);
    expect(find.textContaining('line-BBB'), findsNothing);
  });

  testWidgets('内容为空时显示 emptyHint', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TextViewerPage(
          title: '文本',
          loader: _emptyLoader,
          emptyHint: '尚无内容',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚无内容'), findsOneWidget);
  });

  testWidgets('注入的附加操作渲染在 AppBar', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TextViewerPage(
          title: '文本',
          loader: () async => 'x',
          actionsBuilder: (Future<void> Function() reload, String fullText) =>
              <Widget>[
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: reload,
                  tooltip: '刷新',
                ),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('刷新'), findsOneWidget);
  });
}

Future<String?> _emptyLoader() async => null;
