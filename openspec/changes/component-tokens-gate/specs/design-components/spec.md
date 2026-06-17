## ADDED Requirements

### Requirement: 组件属性全绑 token（审计门禁）
组件的所有可 token 化属性——颜色、圆角、间距、字号、结构尺寸——必须（MUST）绑定变量，不得（MUST NOT）硬编码。唯一豁免：disabled 态的 opacity 色（Figma「paint 绑 color 变量 + opacity」冲突的平台限制，已查证）。必须（MUST）有审计门禁扫描组件并报告未绑项；新组件（A3）须通过审计方视为完成。

#### Scenario: 审计报告未绑
- **当** 对组件运行 token 绑定审计
- **则** 列出所有未绑变量的可 token 化属性（fills / strokes 色、圆角、内距、itemSpacing、结构尺寸）

#### Scenario: disabled opacity 豁免
- **当** 审计遇到 `State=disabled` 的 opacity 色
- **则** 豁免、不报为违规（Figma paint 绑定 + opacity 冲突所致）

#### Scenario: 通过判据
- **当** 组件除豁免项外无未绑属性
- **则** 审计通过

### Requirement: 组件结构尺寸绑 comp token
组件结构尺寸（容器高、图标尺寸、描边宽等）必须（MUST）绑 comp 层 token，不得（MUST NOT）用魔法数字。

#### Scenario: 结构尺寸绑 comp
- **当** 检查 Button 容器高 / 图标尺寸 / 描边宽
- **则** 各绑对应 `comp/button/*` token
