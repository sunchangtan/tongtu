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

### Requirement: comp 层组件 token
comp 层必须（MUST）作为组件 token 的单一入口：既以 alias 引用 sys 实现语义透传（颜色引 `sys/color`、尺寸引 `sys/ui`），又承载 sys 语义层无对应档的组件固有值（如按钮容器高 / 图标尺寸 / 描边宽）；comp 颜色必须（MUST）随明暗（经引用的 sys 明暗自动得明暗两套）。comp token 存于 `tokens/comp.json`（DTCG），必须（MUST）随同一管线生成 Flutter / CSS / TS 三端产物，与 sys 同源同值，不得（MUST NOT）各端硬编码。

#### Scenario: comp 引 sys（语义透传）
- **当** 查看 comp 颜色 / 可对应 sys 的尺寸 token
- **则** 经 alias 引 sys（如 `comp/button/filled/container-color` → `sys/color/primary`、`comp/button/padding-horizontal` → `sys/ui/space/xl`）

#### Scenario: comp 承载固有值
- **当** 查看 sys 无对应档的组件尺寸（容器高 / 图标尺寸 / 描边宽）
- **则** 由 comp 直接承载字面值

#### Scenario: comp 颜色随明暗
- **当** 在明、暗主题下解析同一 comp 颜色
- **则** 经引用的 sys 明暗，得明暗两套值

#### Scenario: comp 三端产物
- **当** 运行生成管线
- **则** comp token（颜色明暗 + 尺寸）生成 Flutter / CSS / TS 产物，可被三端组件引用

### Requirement: disabled 语义色（带 alpha）
sys 层必须（MUST）提供 disabled 语义色（container / content / icon / border），以**带 alpha 的颜色变量**表达（`on-surface` 预乘 12% / 38%，明暗 mode 各算），不得（MUST NOT）依赖图层 opacity。container / content 为实色，icon / border 应当（SHALL）以 alias 引用同值变量。

#### Scenario: disabled 带 alpha
- **当** 查看 `sys/color/disabled-*`
- **则** 为带 alpha 的颜色变量（α 烤进值），明暗 mode 各预乘 `on-surface`

#### Scenario: 绑定即得透明度
- **当** 组件把 disabled 变量绑到 fill / stroke 的 color
- **则** 透明度来自变量 α（Figma 自动映射为 paint.opacity），无需手设图层 opacity

### Requirement: 多级别名解析（comp→sys→ref）
管线必须（MUST）解析任意深度的 token 别名链（如 comp→sys→ref），产物为最终解析值（终值），不得（MUST NOT）输出中间引用；被引用的 token 必须（MUST）与引用方同处一个解析 source 集合，否则解析应当（SHALL）报错。

#### Scenario: 多级链解析为终值
- **当** comp token 经 sys 引用 ref（如 `comp/button/filled/container-color` → `sys/color/primary` → `ref/indigo/40`）
- **则** 产物为最终色值（终值），非中间引用名

#### Scenario: 同 source 集合
- **当** 引用链中某 token 不在解析 source 集合
- **则** 解析报错（须将其纳入 source）

