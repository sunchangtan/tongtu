import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/ui/app_theme.dart';
import 'package:tongtu/ui/components/button.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('TongtuButton variant → M3 widget 映射', () {
    testWidgets('filled → FilledButton', (WidgetTester t) async {
      await t.pumpWidget(
        _wrap(
          TongtuButton(
            variant: TongtuButtonVariant.filled,
            onPressed: () {},
            label: 'B',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('tonal → FilledButton（.tonal 工厂）', (WidgetTester t) async {
      await t.pumpWidget(
        _wrap(
          TongtuButton(
            variant: TongtuButtonVariant.tonal,
            onPressed: () {},
            label: 'B',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('outlined → OutlinedButton', (WidgetTester t) async {
      await t.pumpWidget(
        _wrap(
          TongtuButton(
            variant: TongtuButtonVariant.outlined,
            onPressed: () {},
            label: 'B',
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('text → TextButton', (WidgetTester t) async {
      await t.pumpWidget(
        _wrap(
          TongtuButton(
            variant: TongtuButtonVariant.text,
            onPressed: () {},
            label: 'B',
          ),
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('elevated → ElevatedButton', (WidgetTester t) async {
      await t.pumpWidget(
        _wrap(
          TongtuButton(
            variant: TongtuButtonVariant.elevated,
            onPressed: () {},
            label: 'B',
          ),
        ),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  testWidgets('disabled：onPressed 为 null', (WidgetTester t) async {
    await t.pumpWidget(
      _wrap(
        const TongtuButton(
          variant: TongtuButtonVariant.filled,
          onPressed: null,
          label: 'B',
        ),
      ),
    );
    final FilledButton btn = t.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('leadingIcon → 渲染图标', (WidgetTester t) async {
    await t.pumpWidget(
      _wrap(
        TongtuButton(
          variant: TongtuButtonVariant.filled,
          onPressed: () {},
          label: 'B',
          leadingIcon: const Icon(Icons.add),
        ),
      ),
    );
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  group('样式来自 theme（不写死）', () {
    test('component themes 已配置 Button 样式', () {
      expect(AppTheme.light.filledButtonTheme.style, isNotNull);
      expect(AppTheme.light.outlinedButtonTheme.style, isNotNull);
      expect(AppTheme.light.textButtonTheme.style, isNotNull);
      expect(AppTheme.light.elevatedButtonTheme.style, isNotNull);
    });

    test('ThemeExtension TongtuTokens 已注册', () {
      final TongtuTokens? tokens = AppTheme.light.extension<TongtuTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.buttonMinHeight, 40);
    });
  });
}
