import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/core/log_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('com.dingqi.tongtu/core');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('LogStore 合并读取全量日志（旧在前）、定位当前文件、清空', () async {
    final Directory dir = Directory.systemTemp.createTempSync('logstore_test');
    final File old = File('${dir.path}/core-old.log')
      ..writeAsStringSync('旧日志\n');
    final File cur = File('${dir.path}/core.log')..writeAsStringSync('新日志\n');
    old.setLastModifiedSync(DateTime(2020));
    cur.setLastModifiedSync(DateTime(2021));

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      return call.method == 'logDir' ? dir.path : null;
    });

    final LogStore store = LogStore();
    final String content = await store.readAll();
    expect(content, contains('旧日志'));
    expect(content, contains('新日志'));
    // 旧在前、最新在后（按修改时间合并）
    expect(content.indexOf('旧日志') < content.indexOf('新日志'), isTrue);
    expect(await store.currentLogFile(), cur.path);

    await store.clear();
    expect(cur.existsSync(), isFalse);
    expect(old.existsSync(), isFalse);

    messenger.setMockMethodCallHandler(channel, null);
    dir.deleteSync(recursive: true);
  });

  test('LogStore 目录不存在时返回空', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      return call.method == 'logDir' ? '/nonexistent/path/xyz123' : null;
    });
    final LogStore store = LogStore();
    expect(await store.readAll(), '');
    expect(await store.currentLogFile(), isNull);
    messenger.setMockMethodCallHandler(channel, null);
  });
}
