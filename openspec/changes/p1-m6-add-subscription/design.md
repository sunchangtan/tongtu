# 设计：增强「添加订阅」（对齐 clashmi）

## 1. 背景与现状

订阅 tab（`subscriptions_page.dart`）FAB 弹 `_AddSubscriptionDialog`：名称(可选) + 订阅链接 + 添加，`SubscriptionStore.fetch`（硬编码 UA `clash.meta`）校验后 `SubscriptionsStore.add(name,url)` 入库。缺多来源导入、自动更新、UA 配置。clashmi「添加配置」是全屏页，含 URL/内容/剪贴板/扫码导入 + 名称 + 更新间隔 + UserAgent。

## 2. 目标 / 非目标

**目标**：添加订阅对齐 clashmi——四来源导入（URL/内容/剪贴板/扫码）、每订阅自动更新间隔、自定义 UA；软件本地可测（相机/真机触发除外）。

**非目标（YAGNI）**：前台周期轮询自动更新（仅启动时检查到期）；「优先机场设置」间隔；订阅分组/排序。

## 3. 关键设计决策

### 决策 1：弹窗 → 全屏 `AddSubscriptionPage`
订阅 tab FAB `push(AddSubscriptionPage(store: ...))`。字段：名称（可选，默认 host）、输入框（多行，URL 或内容）、导入按钮行（从剪贴板 / 扫码）、更新间隔（下拉：关/6h/12h/24h/自定义）、User-Agent（可选）、添加按钮。注入点：`clipboardReader`（默认 `Clipboard.getData`）、`scanner`（默认 push `ScanPage`）便于测试。

### 决策 2：模型扩展 `Subscription`
加 `String? userAgent`（null→默认 clash.meta）、`int updateIntervalMinutes`（0=关）、`int lastUpdatedMs`（0=从未）。`toJson/fromJson` 带默认回退（旧 JSON 缺字段安全）。

### 决策 3：四来源导入
- **URL**：`SubscriptionStore.isValidUrl(input)` → `fetch(url, userAgent: ua)`。
- **直接内容**：非 URL → 视为原始 clash YAML → `SubscriptionStore.validateContent(content)`（暴露 `_validateClashConfig`）校验 → `addContent`（url 空、interval 强制 0，不参与自动更新）。
- **剪贴板**：按钮读 `clipboardReader()` 填入输入框（不直接入库，用户可再编辑）。
- **扫码**：按钮 `await scanner(context)` → push `ScanPage`（`mobile_scanner`，首个条码 `Navigator.pop(text)`）→ 扫到文本填入输入框。

### 决策 4：`fetch` 加 UA 参数
`fetch(url, {http.Client? client, String? userAgent})`：UA 取 `userAgent ?? 'clash.meta'`。`SubscriptionsStore` 的 fetcher 注入签名扩展为 `(url, userAgent)`。

### 决策 5：Store API
- `add(name, url, {String? userAgent, int intervalMinutes = 0})`：fetch(带 UA) 校验 → 入库存 UA/interval/lastUpdated=now。
- `addContent(name, content)`：校验原始内容 → 入库（url=''、UA=null、interval=0、落盘 content）。
- `update(id)`：用该订阅存储 UA 重拉，成功置 lastUpdatedMs=now。
- `setAutoUpdate(id, intervalMinutes)` / `setUserAgent(id, ua)`：编辑既有订阅（后续编辑页用，本期最小可不接 UI）。
- `dueForAutoUpdate(int nowMs)`：返回 `interval>0 && url 非空 && nowMs−lastUpdatedMs ≥ interval*60000` 的 id 列表。

### 决策 6：自动更新触发
`HomeShell._init` 加载后：`for id in store.dueForAutoUpdate(now): store.update(id)`（尽力、异步、失败不阻塞 UI；逐个 await 防并发风暴）。`now` 由 `DateTime.now().millisecondsSinceEpoch` 取（注入点测试用）。仅启动时检查。

### 决策 7：扫码依赖与权限
`mobile_scanner`（维护良好、iOS 支持）。iOS `Runner/Info.plist` 加 `NSCameraUsageDescription`（中文说明）。`ScanPage` 极薄：`MobileScanner(onDetect: 首个非空 → pop)`。相机本身真机验证；`AddSubscriptionPage` 的扫码经注入 `scanner` 回调单测（不碰相机）。

## 4. 数据流

- 添加(URL)：输入 URL（或剪贴板/扫码填入）→ 选间隔/UA → 添加 → `add(name,url,ua,interval)` fetch 校验 → 入库落盘。
- 添加(内容)：粘贴/扫码得到 YAML → 添加 → `addContent` 本地校验 → 入库落盘。
- 自动更新：启动 `_init` → `dueForAutoUpdate(now)` → 逐个 `update`（带 UA）→ 置 lastUpdated。

## 5. Risks / Trade-offs

- **[相机权限/依赖]** mobile_scanner + 相机权限 → Mitigation：扫码 UI 极薄；逻辑经注入回调单测；真机 gate 验证相机；缺权限时系统弹窗，扫码失败不影响其余导入。
- **[内容 vs URL 误判]** 输入歧义 → Mitigation：`isValidUrl` 判 http/https，否则按内容；内容再经 YAML 校验，非法则报错不入库。
- **[自动更新风暴/阻塞]** 启动多订阅同时更新 → Mitigation：逐个 await 串行；失败跳过；不阻塞首帧（异步 fire-and-forget）。
- **[旧 JSON 缺新字段]** → Mitigation：fromJson 字段默认回退（UA=null/interval=0/lastUpdated=0）。

## 6. 测试

- **Store 单测**：新字段持久化往返；`addContent`（合法入库/非法不入库/url 空）；`add` 带 UA 透传给 fetcher + interval/lastUpdated 落库；`update` 用存储 UA + 置 lastUpdated；`dueForAutoUpdate`（间隔关/未到期/到期/url 空跳过）。
- **AddSubscriptionPage widget**：剪贴板按钮填入（mock clipboardReader）；URL 输入→add；内容输入→addContent；扫码注入结果填入；间隔/UA 字段；空输入禁用。
- **ScanPage**：扫到条码 → 返回文本（onDetect 逻辑，不碰真实相机）。

## 7. Open Questions

- mobile_scanner 版本与 Flutter 3.44.2/Dart 3.8 兼容性——实施首步 `flutter pub add` 验证解析。
- 编辑既有订阅的 UA/间隔（编辑页）——本期添加页先支持新建设置；既有订阅编辑可最小（备注）或留后续，实施时按成本定。
