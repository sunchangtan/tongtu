## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: 多级别名解析（comp→sys→ref）
管线必须（MUST）解析任意深度的 token 别名链（如 comp→sys→ref），产物为最终解析值（终值），不得（MUST NOT）输出中间引用；被引用的 token 必须（MUST）与引用方同处一个解析 source 集合，否则解析应当（SHALL）报错。

#### Scenario: 多级链解析为终值
- **当** comp token 经 sys 引用 ref（如 `comp/button/filled/container-color` → `sys/color/primary` → `ref/indigo/40`）
- **则** 产物为最终色值（终值），非中间引用名

#### Scenario: 同 source 集合
- **当** 引用链中某 token 不在解析 source 集合
- **则** 解析报错（须将其纳入 source）
