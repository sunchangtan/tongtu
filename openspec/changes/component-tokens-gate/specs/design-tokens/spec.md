## ADDED Requirements

### Requirement: comp 层组件 token
组件级固有尺寸（sys 语义层无对应档者，如按钮容器高 / 图标尺寸 / 描边宽）应当（SHALL）以 comp 层 token 表达，存于 `tokens/comp.json`（DTCG）；comp token 必须（MUST）随同一管线生成 Flutter / CSS / TS 三端产物，与 sys 同源同值，不得（MUST NOT）各端硬编码。

#### Scenario: comp 层与 sys 分明
- **当** 查看 token 源
- **则** 存在 comp 层（如 `comp/button/*`），sys=语义、comp=组件固有尺寸，层次分明

#### Scenario: comp 三端产物
- **当** 运行生成管线
- **则** comp token 生成 Flutter / CSS / TS 产物，可被三端组件引用
