import 'package:flutter/material.dart';

import 'core/theme_controller.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  runApp(const TongtuApp());
}

/// 通途应用根组件。
class TongtuApp extends StatelessWidget {
  const TongtuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return MaterialApp(
          title: '通途',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const HomeShell(),
        );
      },
    );
  }
}
