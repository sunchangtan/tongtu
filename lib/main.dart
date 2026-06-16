import 'package:flutter/material.dart';

void main() {
  runApp(const TongtuApp());
}

/// 通途应用根组件（M1 骨架占位，连接界面在后续任务实现）。
class TongtuApp extends StatelessWidget {
  const TongtuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通途',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('通途 · M1 骨架'),
        ),
      ),
    );
  }
}
