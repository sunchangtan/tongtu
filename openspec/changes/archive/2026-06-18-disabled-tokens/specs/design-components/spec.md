## MODIFIED Requirements

### Requirement: 组件属性全绑 token（审计门禁）
组件的所有可 token 化属性——颜色、圆角、间距、字号、结构尺寸——必须（MUST）绑定变量，不得（MUST NOT）硬编码。disabled 态颜色必须（MUST）绑**带 alpha 的 disabled 语义色变量**（α 由变量提供，不用手设图层 opacity）。唯一豁免：padding=0（无内距）。必须（MUST）有审计门禁扫描组件并报告未绑项；新组件（A3）须通过审计方视为完成。

#### Scenario: 审计报告未绑
- **当** 对组件运行 token 绑定审计
- **则** 列出所有未绑变量的可 token 化属性（fills / strokes 色、圆角、内距、itemSpacing、结构尺寸）

#### Scenario: disabled 全绑（无豁免）
- **当** 审计遇到 disabled 态的 fill / stroke 色
- **则** 须为绑定的 disabled 语义色变量（带 alpha）；未绑则报为违规（不再豁免）

#### Scenario: 通过判据
- **当** 组件除 padding=0 外无未绑属性
- **则** 审计通过
