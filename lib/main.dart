import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

void main() {
  runApp(const TongtuApp());
}

/// 通途应用根组件。
class TongtuApp extends StatelessWidget {
  const TongtuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通途',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
