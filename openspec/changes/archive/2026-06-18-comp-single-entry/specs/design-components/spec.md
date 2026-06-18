## MODIFIED Requirements

### Requirement: Button 绑 token
Button 的颜色、圆角、文字内距、结构尺寸必须（MUST）经 `comp/button/*` 单一入口取用（字体除外，走全局 type scale），不得（MUST NOT）硬编码、不得（MUST NOT）跳过 comp 直接读 `sys/*` 或框架 `ColorScheme`；`comp/button/*` 内部必须（MUST）经 alias 引 sys（颜色 → `sys/color`、内距 / 圆角 → `sys/ui`）。

#### Scenario: 颜色只读 comp
- **当** 检查 filled 变体
- **则** 容器色取 `comp/button/filled/container-color`（内部引 `sys/color/primary`）、文字色取 `comp/button/filled/label-color`（内部引 `sys/color/on-primary`）

#### Scenario: 圆角 / 内距只读 comp
- **当** 检查任一变体
- **则** 圆角取 `comp/button/shape`（引 `sys/ui/radius/full`）、水平内距取 `comp/button/padding-horizontal`（引 `sys/ui/space/xl`）

#### Scenario: 结构尺寸只读 comp
- **当** 检查容器高 / 图标尺寸 / 描边宽
- **则** 各取 `comp/button/container-height`、`comp/button/icon-size`、`comp/button/outline-width`

#### Scenario: 不跳读 sys
- **当** 审视 Button 三端取色 / 取尺寸
- **则** 经 `comp/button/*` 单一入口，不直接读 `sys/*` 或 `ColorScheme`（字体走 type scale 除外）

## ADDED Requirements

### Requirement: 组件 token 单一入口（comp）
组件的所有可 token 化外观属性（颜色、圆角、内距、结构尺寸）必须（MUST）经 `comp/<组件>/*` 单一入口取用，不得（MUST NOT）跳过 comp 直接读 `sys/*` 或框架默认（如 `ColorScheme`）；comp 内部应当（SHALL）经 alias 引 sys 实现语义透传。字体不在此入口（走全局 type scale）。此入口必须（MUST）使组件级定制成为可能——改 `comp/<组件>/*` 仅影响该组件，不动全局 sys。

#### Scenario: 组件只读 comp
- **当** 审视组件三端取用的颜色 / 尺寸
- **则** 均来自 `comp/<组件>/*`，无直接读 `sys/*` 或 `ColorScheme`

#### Scenario: 组件级定制
- **当** 仅修改某组件的 `comp/<组件>/*` token
- **则** 只该组件外观改变，全局 sys 与其他组件不受影响

#### Scenario: 字体例外
- **当** 查看组件字体来源
- **则** 取自全局 type scale（`type/*`），不经 comp
