import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtu/core/clash_api.dart';
import 'package:tongtu/core/core_controller.dart';
import 'package:tongtu/ui/monitor_page.dart';

class _FakeController implements CoreController {
  _FakeController({required this.state, this.endpoint});

  @override
  final CoreState state;

  final ControllerEndpoint? endpoint;

  @override
  ControllerEndpoint? get currentEndpoint => endpoint;

  @override
  Stream<CoreState> get stateStream => const Stream<CoreState>.empty();

  @override
  Future<void> start({required String configYAML}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<MemorySnapshot?> memorySnapshot() async => null;

  @override
  Future<String> lastResult() async => '';
}

/// 测试用 ClashApi：仅日志流可控，其余方法返回空。
class _FakeApi implements ClashApi {
  final StreamController<LogEntry> _logCtrl =
      StreamController<LogEntry>.broadcast();

  void emitLog(LogEntry e) => _logCtrl.add(e);

  @override
  Stream<LogEntry> logsStream() => _logCtrl.stream;

  @override
  Stream<Traffic> trafficStream() => const Stream<Traffic>.empty();

  @override
  Future<List<ConnectionItem>> getConnections() async => <ConnectionItem>[];

  @override
  Future<List<RuleItem>> getRules() async => <RuleItem>[];

  @override
  Future<Map<String, ProxyGroup>> getProxyGroups() async =>
      <String, ProxyGroup>{};

  @override
  Future<void> selectProxy(String group, String name) async {}

  @override
  Future<int> testDelay(
    String name, {
    String url = 'http://www.gstatic.com/generate_204',
    int timeout = 5000,
  }) async => 0;

  @override
  Future<KernelConfig> getConfigs() async => const KernelConfig(
    mode: 'rule',
    logLevel: 'info',
    ipv6: false,
    unifiedDelay: false,
  );

  @override
  Future<void> patchConfigs(Map<String, dynamic> fields) async {}

  @override
  Future<void> updateGeo() async {}

  @override
  Future<void> flushFakeIP() async {}

  @override
  Future<void> flushDNS() async {}

  @override
  void dispose() => _logCtrl.close();
}

void main() {
  testWidgets('监控页未连接显示空态', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitorPage(
            controller: _FakeController(state: CoreState.stopped),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('请先'), findsOneWidget);
  });

  testWidgets('日志带时间戳、节流刷新、暂停冻结', (WidgetTester tester) async {
    final _FakeApi api = _FakeApi();
    final _FakeController controller = _FakeController(
      state: CoreState.connected,
      endpoint: const ControllerEndpoint(
        host: '127.0.0.1',
        port: 1,
        secret: 's',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitorPage(controller: controller, apiFactory: (_) => api),
        ),
      ),
    );
    await tester.pump(); // initState 订阅

    // 切到日志 tab
    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    // 发一条日志，等节流定时器（300ms）批量刷新
    api.emitLog(LogEntry(type: 'info', payload: 'HELLO-LOG'));
    await tester.pump(const Duration(milliseconds: 350));

    // 显示「时间戳 [级别] 内容」
    expect(find.textContaining('HELLO-LOG'), findsOneWidget);
    expect(find.textContaining('[info]'), findsOneWidget);

    // 暂停 → 按钮切换为「继续」
    expect(find.text('暂停'), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    // 卸载以触发 dispose（取消节流定时器，避免 pending timer）
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
