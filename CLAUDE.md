# 通途（Tongtu）项目规范

跨平台代理工具：Flutter + 官方 mihomo 内核。总体设计见 `docs/design/architecture.md`（唯一上位设计文档，当前 v1.1）。

## 开发流程（强制）

三层体系，缺一不可：

1. **CLAUDE.md 全局 8 步流程**定节奏：方案设计 → 确认方案 → 设计文档 → 任务拆解 → **确认计划（门控，未确认不得编码）** → 编码 → 进度更新 → 测试归档。
2. **OpenSpec 定结构**：每个阶段/特性一个 change（`openspec/changes/<id>/`），四工件齐备（proposal/design/specs/tasks）并通过 `openspec validate <id>`（必须在仓库根目录运行）才能进入实施；实施按 tasks.md 勾选推进；完成且验证通过后 `openspec archive` 合入 `openspec/specs/`。
3. **Superpowers 定手法**：新需求先 brainstorming；实施用 test-driven-development（specs 的「场景」即测试用例来源）；遇 bug 用 systematic-debugging；宣称完成前必须 verification-before-completion（拿到命令输出证据）。

## 文档语言约定（强制）

- 全部文档、代码注释、提交信息一律中文。
- 唯一例外（OpenSpec CLI 硬解析关键字保留英文）：specs 增量文件的 `## ADDED/MODIFIED/REMOVED/RENAMED Requirements`、`### Requirement:`、`#### Scenario:` 标头；每条需求正文须含字面量 `SHALL`/`MUST`，写法为中文规范词加括注（「必须（MUST）」「应当（SHALL）」「不得（MUST NOT）」）；场景子弹项用 **当**/**则**；tasks.md 复选框 `- [ ] X.Y` 格式不变。

## 技术红线

- 内核只用官方 `github.com/metacubex/mihomo`（锁 release tag）；不 fork、不维护长期补丁；临时补丁须 `go.mod replace` + 仓库内补丁文件显式可见。
- 配置消费 mihomo 原生 YAML，不发明私有格式；与 metacubex 官方 wiki 推荐配置保持兼容。
- 许可证 GPL-3.0；可参考同许可的 FlClash 代码，clashmi 仅作 UI 设计参照、不复制代码。
- iOS NE 扩展内存红线：常驻 < 40MiB、峰值 < 50MiB（jetsam 限额），相关改动必须附真机内存数据。

## architecture.md 维护协议

- **职责**：只记录「当前为真」的全局架构事实与跨阶段决策；能力级需求事实归 `openspec/specs/`，变更级细节归各 change 的 design.md，历史归 git 与 §13 版本记录。
- **更新时机**：① 每次 `openspec archive` 前检查该 change 是否推翻/细化了全局决策，是则同步更新；② 重大方向变更（如 P0 内存验证 no-go）；③ 阶段完成时更新路线图状态。
- **更新动作**（三处缺一不可）：修改正文 + §13 版本记录表加一行 + 头部「版本/日期」同步；用独立的 `docs:` 提交。
- **门槛**：任何改变已确认决策的更新，须先经用户确认再落盘。
