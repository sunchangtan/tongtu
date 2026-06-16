import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/main.dart';

void main() {
  testWidgets('应用骨架可渲染', (tester) async {
    await tester.pumpWidget(const TongtuApp());
    expect(find.text('通途 · M1 骨架'), findsOneWidget);
  });
}
