import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongtu/config/run_params_store.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('空 prefs：load 取默认值', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    final RunParams p = store.params;
    expect(p.mode, 'rule');
    expect(p.logLevel, 'info');
    expect(p.ipv6, isFalse);
    expect(p.unifiedDelay, isTrue);
    expect(p.tcpConcurrent, isTrue);
    expect(p.sniff, isFalse);
    expect(p.allowLan, isFalse);
    expect(p.mixedPort, 7890);
    expect(p.delayTestUrl, contains('generate_204'));
    expect(p.delayTestTimeoutMs, 5000);
  });

  test('save 持久化往返', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.save(
      store.params.copyWith(mode: 'global', ipv6: true, mixedPort: 1080),
    );
    final RunParamsStore store2 = RunParamsStore();
    await store2.load();
    expect(store2.params.mode, 'global');
    expect(store2.params.ipv6, isTrue);
    expect(store2.params.mixedPort, 1080);
  });

  test('save 通知监听者', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    int n = 0;
    store.addListener(() => n++);
    await store.save(store.params.copyWith(mode: 'direct'));
    expect(n, 1);
  });

  test('种子化：无持久化时从订阅配置读初值', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    final bool seeded = await store.seedFromConfig(
      'mode: global\nlog-level: debug\nproxies: []\n',
    );
    expect(seeded, isTrue);
    expect(store.params.mode, 'global');
    expect(store.params.logLevel, 'debug');
  });

  test('种子化：从配置 sniffer.enable 读嗅探偏好', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.seedFromConfig(
      'sniffer:\n  enable: true\nproxies: []\n',
    );
    expect(store.params.sniff, isTrue);
  });

  test('种子化幂等：已持久化则不再种子化', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.seedFromConfig('mode: global\nproxies: []\n'); // 首次
    final RunParamsStore store2 = RunParamsStore();
    await store2.load(); // 已持久化
    final bool seeded = await store2.seedFromConfig(
      'mode: direct\nproxies: []\n',
    );
    expect(seeded, isFalse);
    expect(store2.params.mode, 'global'); // 保留首次
  });

  test('applyToConfig：配置无 mode 键 → 新增', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.save(store.params.copyWith(mode: 'global'));
    final Map<dynamic, dynamic> doc =
        loadYaml(store.applyToConfig('proxies:\n  - name: x\n')) as Map;
    expect(doc['mode'], 'global');
    expect(doc['proxies'], isNotNull); // 保留其余
  });

  test('applyToConfig：配置有 mode 键 → 改写', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.save(store.params.copyWith(mode: 'direct'));
    final Map<dynamic, dynamic> doc =
        loadYaml(store.applyToConfig('mode: rule\nproxies: []\n')) as Map;
    expect(doc['mode'], 'direct');
  });

  test('applyToConfig：默认写入标准键', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    final Map<dynamic, dynamic> doc =
        loadYaml(store.applyToConfig('proxies: []\n')) as Map;
    expect(doc['mode'], 'rule');
    expect(doc['log-level'], 'info');
    expect(doc['ipv6'], isFalse);
    expect(doc['unified-delay'], isTrue);
    expect(doc['tcp-concurrent'], isTrue);
    expect(doc['allow-lan'], isFalse);
    expect(doc['mixed-port'], 7890);
  });

  test('applyToConfig：sniff=true 写 sniffer 段', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.save(store.params.copyWith(sniff: true));
    final Map<dynamic, dynamic> doc =
        loadYaml(store.applyToConfig('proxies: []\n')) as Map;
    expect((doc['sniffer'] as Map)['enable'], isTrue);
  });

  test('applyToConfig：allow-lan + mixed-port 局域网共享', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    await store.save(store.params.copyWith(allowLan: true, mixedPort: 1080));
    final Map<dynamic, dynamic> doc =
        loadYaml(store.applyToConfig('proxies: []\n')) as Map;
    expect(doc['allow-lan'], isTrue);
    expect(doc['mixed-port'], 1080);
  });

  test('applyToConfig：非法 YAML 不抛、原样返回', () async {
    final RunParamsStore store = RunParamsStore();
    await store.load();
    const String bad = ':\n  - [unbalanced';
    expect(store.applyToConfig(bad), bad);
  });
}
