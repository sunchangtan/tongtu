## ADDED Requirements

### Requirement: disabled 语义色（带 alpha）
sys 层必须（MUST）提供 disabled 语义色（container / content / icon / border），以**带 alpha 的颜色变量**表达（`on-surface` 预乘 12% / 38%，明暗 mode 各算），不得（MUST NOT）依赖图层 opacity。container / content 为实色，icon / border 应当（SHALL）以 alias 引用同值变量。

#### Scenario: disabled 带 alpha
- **当** 查看 `sys/color/disabled-*`
- **则** 为带 alpha 的颜色变量（α 烤进值），明暗 mode 各预乘 `on-surface`

#### Scenario: 绑定即得透明度
- **当** 组件把 disabled 变量绑到 fill / stroke 的 color
- **则** 透明度来自变量 α（Figma 自动映射为 paint.opacity），无需手设图层 opacity
