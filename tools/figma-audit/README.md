# Figma 组件 token 绑定审计门禁

强制组件的可 token 化属性**全绑变量**（`design-components` 能力的「组件属性全绑 token」需求）。**A3 每个组件建完都要跑此审计，0 未绑（除豁免）才算完成。**

## 用法

agent 用 Figma MCP `use_figma` 执行 `audit-component.js` 的内容（figma 全局环境）；先把脚本顶部 `COMPONENT_SET_ID` 换成目标组件的 Component Set id。

## 通过判据

返回 `✅ 审计通过：0 未绑`。否则返回违规清单，须修到 0。

## 检查项

容器 / 描边 / 文字 / 图标 fill 色、描边宽、圆角、内距、itemSpacing、容器高、图标尺寸——均须绑变量（`sys/*` 或 `comp/*` token）。

## 豁免（合理且显式）

1. **disabled 态的 opacity 色**：Figma「paint 绑 color 变量 + opacity」冲突（opacity 被吞，已查证的平台限制）。disabled 容器/文字/图标/描边用固定 `on-surface` + opacity，无法绑——代码端 disabled 由框架（Flutter M3 / MUI）自带处理，不依赖此。
2. **padding=0**：无内距，不需 token。

## 已知 Figma 细节

- `setBoundVariable('strokeWeight', v)` 会展开绑到 `strokeTopWeight/Bottom/Left/Right` 四边，`boundVariables` 无 `strokeWeight` key——故审计查 `strokeTopWeight`。
