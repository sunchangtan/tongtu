import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/config/subscriptions_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int idCounter;

  // 默认 fetcher：返回合法配置 + 流量信息
  Future<SubscriptionInfo> okFetcher(String url) async =>
      const SubscriptionInfo(
        ok: true,
        content: 'proxies:\n  - name: x\n',
        total: 100,
        download: 30,
      );

  SubscriptionsStore makeStore({
    Future<SubscriptionInfo> Function(String)? fetcher,
  }) {
    idCounter = 0;
    return SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'id${++idCounter}',
      fetcher: fetcher ?? okFetcher,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tmp = await Directory.systemTemp.createTemp('subs_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('add 入库 + 落盘 + 首条自动设为当前', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    final SubscriptionInfo info = await store.add('订阅A', 'https://a.com');
    expect(info.ok, isTrue);
    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.name, '订阅A');
    expect(store.subscriptions.first.url, 'https://a.com');
    expect(store.currentId, 'id1');
    expect(await store.currentContent(), contains('proxies'));
  });

  test('add 校验失败不入库', () async {
    final SubscriptionsStore store = makeStore(
      fetcher: (String url) async =>
          const SubscriptionInfo(ok: false, message: '非法'),
    );
    await store.load();
    final SubscriptionInfo info = await store.add('A', 'https://a.com');
    expect(info.ok, isFalse);
    expect(store.subscriptions, isEmpty);
  });

  test('多条 + 切换当前', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    await store.add('A', 'https://a.com');
    await store.add('B', 'https://b.com');
    expect(store.subscriptions.length, 2);
    expect(store.currentId, 'id1'); // 首条仍当前
    await store.setCurrent('id2');
    expect(store.currentId, 'id2');
  });

  test('删除当前订阅：转移到首项 + 删除落盘文件', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    await store.add('A', 'https://a.com'); // id1
    await store.add('B', 'https://b.com'); // id2
    await store.setCurrent('id2');
    final File f2 = File('${tmp.path}/configs/id2.yaml');
    expect(f2.existsSync(), isTrue);
    await store.remove('id2');
    expect(store.subscriptions.length, 1);
    expect(store.currentId, 'id1'); // 转移到首项
    expect(f2.existsSync(), isFalse); // 落盘删除
  });

  test('删除最后一条：当前清空', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    await store.add('A', 'https://a.com');
    await store.remove('id1');
    expect(store.subscriptions, isEmpty);
    expect(store.currentId, isNull);
    expect(await store.currentContent(), isNull);
  });

  test('update 重拉刷新 info', () async {
    int calls = 0;
    final SubscriptionsStore store = makeStore(
      fetcher: (String url) async {
        calls++;
        return SubscriptionInfo(
          ok: true,
          content: 'proxies:\n  - name: x\n',
          total: calls * 100,
        );
      },
    );
    await store.load();
    await store.add('A', 'https://a.com'); // calls=1, total=100
    await store.update('id1'); // calls=2, total=200
    expect(store.subscriptions.first.info?.total, 200);
  });

  test('持久化往返（新 store load 读回）', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    await store.add('A', 'https://a.com');
    final SubscriptionsStore store2 = SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'idX',
      fetcher: okFetcher,
    );
    await store2.load();
    expect(store2.subscriptions.length, 1);
    expect(store2.subscriptions.first.url, 'https://a.com');
    expect(store2.currentId, 'id1');
  });

  test('迁移：旧单订阅 → 列表首项并设为当前', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'subscription_url': 'https://old.com',
    });
    await File(
      '${tmp.path}/subscription.yaml',
    ).writeAsString('proxies:\n  - old\n');
    final SubscriptionsStore store = makeStore();
    await store.load();
    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.url, 'https://old.com');
    expect(store.currentId, store.subscriptions.first.id);
    expect(await store.currentContent(), contains('old'));
  });

  test('迁移幂等：再次 load 不重复', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'subscription_url': 'https://old.com',
    });
    await File(
      '${tmp.path}/subscription.yaml',
    ).writeAsString('proxies:\n  - old\n');
    final SubscriptionsStore store = makeStore();
    await store.load();
    await store.load();
    expect(store.subscriptions.length, 1);
  });

  test('空态：load 无数据', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    expect(store.subscriptions, isEmpty);
    expect(store.currentId, isNull);
    expect(await store.currentContent(), isNull);
  });

  test('成功变更通知监听者（跨页同步）', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    int n = 0;
    store.addListener(() => n++);
    await store.add('A', 'https://a.com'); // 1
    await store.add('B', 'https://b.com'); // 2
    await store.setCurrent('id2'); // 3
    await store.update('id1'); // 4
    await store.remove('id1'); // 5
    expect(n, 5); // 每次成功变更各通知一次
  });
}
