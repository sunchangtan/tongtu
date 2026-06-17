# design-tokens Specification

## Purpose
TBD - created by archiving change design-token-sync. Update Purpose after archive.
## Requirements
### Requirement: 设计 token 单一真相源（DTCG 格式）
设计 token 必须（MUST）以 W3C DTCG 格式存放于 `tokens/` 目录，作为三端唯一真相源；token 分 `ref`（基础色）与 `sys`（语义）两层，sys 应当（SHALL）经 alias 引用 ref，各端不得（MUST NOT）硬编码原始色值。

#### Scenario: ref/sys 两层与 alias
- **当** 定义一个语义色 token（如 sys 主色）
- **则** 它经 DTCG alias 引用某个 ref 基础色，而非内联裸色值

#### Scenario: DTCG 标准格式
- **当** 读取 `tokens/` 下任一 token 文件
- **则** token 以 DTCG 的 `$type` / `$value` 表达，可被支持 DTCG 的工具解析

### Requirement: 明暗双主题 token sets
语义色必须（MUST）以明、暗两套 token set 表达（共享同一 ref 基础色层）；维度类 token（间距 / 圆角 / 字号，UI 尺度）无明暗区分，应当（SHALL）为单一 set 供明暗共用。

#### Scenario: 明暗各一套语义色 set
- **当** 查看语义色 token 源
- **则** 存在浅色与深色两套语义色 set，且二者引用同一 ref 层

#### Scenario: 维度单 set 共用
- **当** 查看维度类 token
- **则** 仅一套，明暗主题共用，无重复的明暗值

### Requirement: 生成 Flutter token 产物
管线必须（MUST）由 token 源生成 Flutter 产物 `lib/ui/tokens/tokens.g.dart`，含明、暗两组语义色常量与共享维度常量；该文件应当（SHALL）标记为生成物（GENERATED），不得（MUST NOT）手工编辑。

#### Scenario: 生成明暗两组语义色常量
- **当** 运行生成管线
- **则** `tokens.g.dart` 含浅色与深色两组语义色常量，及一组共享维度常量

#### Scenario: 标记为生成物
- **当** 打开 `tokens.g.dart`
- **则** 顶部注释标明该文件由 token 源生成、勿手改

### Requirement: 生成 CSS token 产物
管线必须（MUST）由同一 token 源生成 CSS 产物，浅色置于 `:root`、深色置于 `[data-theme=dark]`，以 CSS 自定义属性（`var(--x)`）表达；CSS 产物应当（SHALL）框架无关，不得（MUST NOT）绑定任何特定 Web UI 库的主题结构。

#### Scenario: 明暗两主题块
- **当** 运行生成管线
- **则** CSS 产物含 `:root`（浅色）与 `[data-theme=dark]`（深色）两块，各 token 为 CSS 自定义属性

#### Scenario: 框架无关
- **当** Web 端引用 CSS 产物
- **则** 仅依赖标准 CSS 自定义属性，不预设特定组件库的主题结构

### Requirement: app 主题引用生成 token
`app_theme.dart` 必须（MUST）从生成的 `tokens.g.dart` 常量取色，不得（MUST NOT）硬编码品牌色值；其 `AppTheme.light` / `AppTheme.dark` 对外接口应当（SHALL）保持不变（`main.dart` 无需改动）。

#### Scenario: 主题色源自生成常量
- **当** 构建浅色 / 深色主题
- **则** 其品牌关键角色取自 `tokens.g.dart` 的对应明 / 暗常量

#### Scenario: 对外接口不变
- **当** 集成生成 token 后
- **则** `AppTheme.light` / `AppTheme.dark` 接口不变，`main.dart` 无需改动

#### Scenario: 明暗切换正确
- **当** 系统在浅色与深色间切换
- **则** app 主题随对应 token set 正确变化

### Requirement: token 跨栈同值
同一语义 token 在 Flutter 产物与 CSS 产物中的值必须（MUST）一致（同源同值），不得（MUST NOT）因平台不同而漂移。

#### Scenario: Flutter 与 CSS 同值
- **当** 抽取同一语义 token（明 / 暗各一例）
- **则** 其在 `tokens.g.dart` 与 `tokens.css` 中解析出的颜色值相等

### Requirement: typography token 源（M3 type scale）
typography 必须（MUST）以 M3 type scale 表达——display / headline / title / body / label 各 Large / Medium / Small 档；每档应当（SHALL）具备字号、字重、行高、字间距。typography 必须（MUST）以 DTCG typography composite token 存于 `tokens/`，作为单一真相源，不得（MUST NOT）在各端硬编码排版值。

#### Scenario: 完整 type scale 档位
- **当** 查看 typography token 源
- **则** 含 display / headline / title / body / label 各 Large / Medium / Small 档，每档具备 size / weight / lineHeight / letterSpacing

#### Scenario: DTCG composite 格式
- **当** 读取 typography token
- **则** 以 DTCG `$type: typography` 的 composite `$value` 表达，可被支持 DTCG 的工具解析

### Requirement: 生成 Flutter typography 产物
管线必须（MUST）由 typography token 生成 Flutter 产物（`TextTheme` 或 `TextStyle` 常量），供 app 主题与组件统一取用；该产物应当（SHALL）标记为生成物（GENERATED），不得（MUST NOT）手工编辑。

#### Scenario: 生成 Flutter typography
- **当** 运行生成管线
- **则** 产出 Flutter typography（M3 type scale → `TextStyle`），可被 `ThemeData` 或组件引用

### Requirement: 生成 CSS typography 产物
管线必须（MUST）由同一 typography token 生成 CSS 产物（含 font-size / font-weight / line-height / letter-spacing）；CSS 产物应当（SHALL）框架无关，不得（MUST NOT）绑定特定 Web UI 库。

#### Scenario: 生成 CSS typography
- **当** 运行生成管线
- **则** CSS 产物含各 type scale 档的字体属性，供 web 取用

### Requirement: typography 跨栈同值
同一 type scale 档在 Flutter 与 CSS 产物中的字体属性必须（MUST）一致（同源同值），不得（MUST NOT）因平台不同而漂移。

#### Scenario: Flutter 与 CSS typography 同值
- **当** 抽取同一 type scale 档（如 body-large）
- **则** 其字号 / 字重 / 行高在 Flutter 与 CSS 产物中一致

