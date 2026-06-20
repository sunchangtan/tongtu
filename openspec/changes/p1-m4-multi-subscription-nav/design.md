# 设计：导航 IA 重构 + 多订阅管理

## 1. 背景与现状

`SubscriptionStore`（`lib/config/subscription.dart`）为单订阅：`subscription_url`（shared_prefs）+ 完整配置正文落盘单文件 + 来源 url 一致性校验。连接页 HomePage 混了订阅（链接输入/获取配置/流量·到期）与连接（连接按钮/状态/内存/诊断）。底部三 tab：连接（ConnectShell=连接/节点/监控 TabBar）/ 设置 / 内核设置（含运行模式/日志级别/IPv6/维护/配置规则/内核信息）。本次（p1-m3-kernel-settings 0a07574 之后）按用户要求重排 IA + 引入多订阅。

## 2. 目标 / 非目标

**目标**
- 底部导航 连接 / 订阅 / 设置；内核设置降为设置二级；运行模式移连接首页。
- 多订阅管理（增/删/切换/更新），迁移现有单订阅不丢数据。
- 连接页专注连接，订阅 UI 独立到订阅 tab。
- 软件本地完整可测（Store 单测 + widget 测试）。

**非目标（YAGNI）**
- 订阅自动定期更新（仅手动更新按钮）。
- 订阅分组/排序/重命名以外的高级管理。
- 切换订阅自动重连（仅提示手动重连）。

## 3. 关键设计决策

### 决策 1：底部导航 连接 / 订阅 / 设置（修订 app-navigation）
`home_shell` 三 tab 改为 连接(ConnectShell) / 订阅(SubscriptionsPage) / 设置(SettingsPage)，`IndexedStack` 保状态。连接 tab 仍顶部 TabBar（连接/节点/监控）。内核设置不再是底部 tab。

### 决策 2：多订阅模型 + Store（核心）
- `Subscription { String id; String name; String url; SubscriptionInfo? info; }`（info=流量/到期，可空）。
- `SubscriptionsStore`：`List<Subscription>` + `currentId`，序列化为 JSON 存 shared_prefs（key `subscriptions`/`subscription_current`）；每订阅完整配置正文落盘 `configs/<id>.yaml`。
- id 生成：`DateTime.now().microsecondsSinceEpoch` 字符串（测试可注入 id 生成器保证确定性）。
- API：`load()` / `add(name,url)`（fetch 校验后入库）/ `remove(id)` / `setCurrent(id)` / `update(id)`（重拉 content+info）/ `current()` / `currentContent()`（连接用）。
- **迁移**：首次 `load()` 检测旧 `subscription_url`（+ 旧落盘 content）存在且新 `subscriptions` 为空 → 生成一条 `Subscription`（name 默认订阅 host 或「订阅 1」，url=旧 url，content 迁移到 `configs/<id>.yaml`）入库设为 current，清理旧 key。一次性、幂等。

### 决策 3：订阅 tab（SubscriptionsPage）
- 订阅卡列表：名称 / 流量·到期（info）/ 当前选中标记 / 更新按钮 / 删除。
- 顶部「添加订阅」：url 输入 + 名称（可选，默认 host）→ 复用现有 `fetch`+`_validateClashConfig` 校验，成功入库。
- 切换：点卡 `setCurrent`；若已连接弹提示「重连生效」（不自动断）。
- 删除：删除项；删的是 current 则 current 转移到列表首项或清空（提示）。
- 更新：`update(id)` 重拉 content+info，刷新卡片。

### 决策 4：连接页拆分 + 运行模式（修订 HomePage）
- HomePage 移除订阅链接输入/获取配置/流量信息（移订阅 tab）。
- 保留：连接/断开按钮（用 `currentContent()`）、状态、内存卡、诊断。无当前订阅时按钮禁用 + 提示「先去订阅页添加并选择」。
- 新增 `RunModeSelector`（`lib/ui/run_mode_selector.dart`）：连接中经 clash_api `getConfigs` 回填、`patchConfigs({mode})` 热改（乐观+回滚，含未知值防御与 on Exception，沿用 kernel_settings 既有写法）；未连接灰置。

### 决策 5：内核设置降级（修订 kernel-settings）
- `KernelSettingsPage` 移除运行模式组（移连接页），保留 日志级别/IPv6/维护/配置规则/内核信息；**恢复 AppBar('内核设置')**（二级页需标题与返回）。
- `SettingsPage` 加「内核设置」`ListTile`（push KernelSettingsPage，传 controller）。

## 4. 数据流

- 添加订阅：订阅 tab 输入 url → `add` fetch+校验 → 入 list + 落盘 content → 刷新。
- 连接：连接页「连接」→ `currentContent()` 读当前订阅正文 → `controller.start`。无 current 则禁用。
- 切换：订阅 tab 点卡 → `setCurrent` → 已连接提示重连。
- 运行模式：连接页 `RunModeSelector` 连接中 `getConfigs` 回填 + 改 `patchConfigs`。
- 迁移：app 启动首次 `load` 自动迁移旧单订阅。

## 5. Risks / Trade-offs

- **[迁移丢数据]** 旧单订阅 url/content 迁移失败致用户丢配置 → Mitigation：迁移幂等 + 失败保留旧 key 不删；单测覆盖「有旧数据→迁移为首项」。
- **[落盘文件清理]** 删订阅需删对应 `configs/<id>.yaml`，否则残留 → Mitigation：remove 同步删文件；测试验证。
- **[连接用 current 与订阅 tab 不同步]** 切换 current 后连接页按钮状态 → Mitigation：连接页监听/读取 current；切换提示重连。
- **[大改回归]** 多文件重构（Store+4 页）→ Mitigation：Store 与各页独立单测；分组 TDD；保留既有连接/节点/监控逻辑不动。

## 6. 测试

- **SubscriptionsStore 单测**：add/remove/setCurrent/update/current、JSON 往返、content 落盘 per id、删除清文件、**迁移**（旧单订阅→首项 current）、空态。
- **SubscriptionsPage widget**：列表渲染、添加（mock fetch）、切换选中、删除、更新、空态。
- **连接页 widget**：无 current 禁用+提示、有 current 可连接、RunModeSelector 连接中回填+改。
- **内核设置降级**：设置页含「内核设置」入口、KernelSettingsPage 无运行模式、有 AppBar。
- **home_shell**：连接/订阅/设置三 tab、无内核设置底部 tab。

## 7. Open Questions

- 订阅名称默认值：host（如 `10.0.8.4`）vs「订阅 N」——倾向 host（可辨识），实施时定。
- 旧落盘 content 文件路径与新 `configs/<id>.yaml` 的迁移搬运细节——实施首步确认现有落盘路径后定。
