import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/subscription.dart';
import 'package:tongtu/config/subscriptions_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late int idCounter;

  // 默认 fetcher：返回合法配置 + 流量信息（签名含 userAgent）
  Future<SubscriptionInfo> okFetcher(String url, String? ua) async =>
      const SubscriptionInfo(
        ok: true,
        content: 'proxies:\n  - name: x\n',
        total: 100,
        download: 30,
      );

  SubscriptionsStore makeStore({
    Future<SubscriptionInfo> Function(String, String?)? fetcher,
    int Function()? nowGetter,
  }) {
    idCounter = 0;
    return SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'id${++idCounter}',
      fetcher: fetcher ?? okFetcher,
      nowMs: nowGetter,
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
      fetcher: (String url, String? ua) async =>
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
      fetcher: (String url, String? ua) async {
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

  test('不迁移旧单订阅（开发期不兼容旧数据）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'subscription_url': 'https://old.com',
    });
    await File(
      '${tmp.path}/subscription.yaml',
    ).writeAsString('proxies:\n  - old\n');
    final SubscriptionsStore store = makeStore();
    await store.load();
    expect(store.subscriptions, isEmpty); // 旧数据被忽略，不迁移
    expect(store.currentId, isNull);
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

  test('add 透传 userAgent + 落库 interval/lastUpdated + 持久化往返', () async {
    String? seenUa;
    final SubscriptionsStore store = makeStore(
      fetcher: (String url, String? ua) async {
        seenUa = ua;
        return const SubscriptionInfo(ok: true, content: 'proxies:\n  - x\n');
      },
      nowGetter: () => 5000,
    );
    await store.load();
    await store.add(
      'A',
      'https://a.com',
      userAgent: 'myUA',
      intervalMinutes: 360,
    );
    expect(seenUa, 'myUA'); // fetcher 收到 UA
    expect(store.subscriptions.first.userAgent, 'myUA');
    expect(store.subscriptions.first.updateIntervalMinutes, 360);
    expect(store.subscriptions.first.lastUpdatedMs, 5000);

    // 持久化往返：新字段读回
    final SubscriptionsStore store2 = SubscriptionsStore(
      configDir: () async => tmp,
      idGen: () => 'idX',
      fetcher: okFetcher,
    );
    await store2.load();
    expect(store2.subscriptions.first.userAgent, 'myUA');
    expect(store2.subscriptions.first.updateIntervalMinutes, 360);
  });

  test('addContent：合法内容入库（url 空、不 fetch）', () async {
    final SubscriptionsStore store = makeStore(
      fetcher: (String url, String? ua) async => fail('addContent 不应发起 fetch'),
    );
    await store.load();
    final SubscriptionInfo info = await store.addContent(
      '本地',
      'proxies:\n  - name: x\n',
    );
    expect(info.ok, isTrue);
    expect(store.subscriptions.length, 1);
    expect(store.subscriptions.first.url, ''); // 内容订阅无 url
    expect(store.currentId, 'id1');
    expect(await store.currentContent(), contains('proxies'));
  });

  test('addContent：非法内容不入库', () async {
    final SubscriptionsStore store = makeStore();
    await store.load();
    final SubscriptionInfo info = await store.addContent(
      '坏',
      '<html>nope</html>',
    );
    expect(info.ok, isFalse);
    expect(store.subscriptions, isEmpty);
  });

  test('update：用存储 UA 重拉并置 lastUpdated', () async {
    String? seenUa;
    int now = 1000;
    final SubscriptionsStore store = makeStore(
      fetcher: (String url, String? ua) async {
        seenUa = ua;
        return const SubscriptionInfo(ok: true, content: 'proxies:\n  - x\n');
      },
      nowGetter: () => now,
    );
    await store.load();
    await store.add('A', 'https://a.com', userAgent: 'UA1'); // lastUpdated=1000
    now = 9999;
    await store.update('id1');
    expect(seenUa, 'UA1'); // 重拉用存储 UA
    expect(store.subscriptions.first.lastUpdatedMs, 9999);
  });

  test('dueForAutoUpdate：到期/未到期/关闭/无 url', () async {
    final int now = 1000000;
    final SubscriptionsStore store = makeStore(nowGetter: () => now);
    await store.load();
    await store.add('A', 'https://a.com', intervalMinutes: 10); // id1
    await store.add('B', 'https://b.com'); // id2 间隔 0=关
    await store.addContent('C', 'proxies:\n  - x\n'); // id3 无 url
    expect(store.dueForAutoUpdate(now), isEmpty); // 刚加未到期
    expect(store.dueForAutoUpdate(now + 11 * 60000), <String>['id1']); // 仅 A 到期
  });

  test('runDueAutoUpdates：更新到期订阅、刷新 lastUpdated', () async {
    int now = 1000000;
    int calls = 0;
    final SubscriptionsStore store = makeStore(
      fetcher: (String url, String? ua) async {
        calls++;
        return const SubscriptionInfo(ok: true, content: 'proxies:\n  - x\n');
      },
      nowGetter: () => now,
    );
    await store.load();
    await store.add('A', 'https://a.com', intervalMinutes: 10); // calls=1
    await store.add('B', 'https://b.com'); // calls=2，间隔 0 不到期
    now += 11 * 60000; // A 到期
    final int n = await store.runDueAutoUpdates(now);
    expect(n, 1); // 仅 A
    expect(calls, 3); // A 被重拉
    expect(store.subscriptions.first.lastUpdatedMs, now); // 刷新
  });
}
