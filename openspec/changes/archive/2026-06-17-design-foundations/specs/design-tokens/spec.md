## ADDED Requirements

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
