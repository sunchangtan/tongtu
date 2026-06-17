# 通途（Tongtu）Logo 设计规范

- 版本：v1.12
- 日期：2026-06-17
- 状态：设计已定稿（经用户逐项确认）；已在 Figma 落地（含辅助视觉）
- 关联：`docs/design/architecture.md`（上位架构）
- Figma 源文件：`Tongtu Brand`（DZH International 团队）https://www.figma.com/design/7Lt4B6C58u9HoTCvUKNUGR

---

## 1. 设计概念

### 1.1 名称由来
项目名「通途」取自「一桥飞架南北，**天堑变通途**」。代理工具的本质，正是在被阻隔的网络两端之间「架桥」连通——**名字的字面义与产品的功能本质完全重合**，这是 logo 的立足点。

### 1.2 核心意象：双孔拱桥
标志主体是一座**双孔拱桥**——两道相邻的上拱连接左、中、右三个落点，左右为端点圆、中间为两拱交汇的谷。该形态同时承载三层语义，叠合而不冲突：

| 层次 | 含义 | 视觉落点 |
|------|------|----------|
| 古桥 | 「一桥飞架、天堑变通途」 | 双拱并列，呼应卢沟桥／宝带桥等多孔古桥 |
| 字母 M | 致敬官方内核 **mihomo** | 双拱并排的轮廓（两峰一谷）自然读作 M（桥为主、M 为辅的隐藏彩蛋） |
| 代理连通 | 在两端之间建立通路 | 双拱跨接两端、中间谷＝M 的中峰，整体表达穿越连通 |

### 1.3 元素释义
- **双上拱（唯一元素）**：两个上半椭圆「双拼」即图形全部——桥／连通本身；两拱在中央交汇成 M 的中峰，两端为 round cap 线头。
- **纯线、无端点**：早期版本两端有圆点（节点／桥墩），最终去除，回归最简的纯双拱线。

> 设计演进中曾尝试「中墩钥石菱形」与「水中倒影」两个装饰层，最终均移除——前者在粗描边下只露下半、易误读为「向下箭头」，后者削弱极简度。定稿为「纯双拱 + 两端点」，最干净、无歧义。详见 §10。

---

## 2. 标志构成与制图

标准 App 图标画板为 **1024×1024**。几何以该画板的绝对坐标定义，便于 Figma 精确复刻；其它尺寸整体等比缩放。括注给出 160 基准画板的等价值（×6.4 得 1024）。

### 2.1 关键坐标（1024 画板）
- 基线（三落点）y = 691.2（160 基准：108）
- 三落点 x：左 153.6 / 中 512 / 右 870.4（基准：24 / 80 / 136）
- 拱顶 y = 268.8，拱高 = 691.2 − 268.8 = 422.4（基准：66）
- 描边宽 51.2（= 画板宽 5%；基准：8），round cap 线头
- 纯双拱整体垂直居中画板（无端点）

### 2.2 路径定义（1024 画板）
双拱为一条连续矢量（两段上半椭圆用三次贝塞尔近似，魔数 k≈0.5523），**圆头端点（round cap）、圆角连接（round join）**：
```
M153.6 691.2
 C153.6 457.9 233.9 268.8 332.8 268.8
 C431.7 268.8 512   457.9 512   691.2
 C512   457.9 592.3 268.8 691.2 268.8
 C790.1 268.8 870.4 457.9 870.4 691.2
（无端点圆；两端即 round cap 线头）
```
- 描边宽度随画板等比换算（5%），不要固定像素。
- **Figma 注意**：`vectorPaths` 不接受逗号分隔坐标（用空格）；vector bounding box 不含描边外扩，定位时按路径 bbox 左上角对齐。

### 2.3 圆角底板
- App 图标圆角 230（1024×22.5%，基准 rx36），近似 iOS squircle。
- **iOS 导出须为满版方形、不透明、无 alpha、无圆角**（系统自动加圆角）。圆角 230 仅用于 macOS／Web 等需自带圆角处；圆角 512＝圆形遮罩。

---

## 3. 配色规范

### 3.1 主色板（已落为 Figma 变量集合 `Brand Colors`）
| 名称 | 变量名 | 用途 | HEX |
|------|--------|------|-----|
| 靛蓝 Indigo | `brand/indigo` | 渐变起点 / 单色主色 / 横版主标 | `#3F51B5` |
| 蓝青 Cyan | `brand/cyan` | 渐变终点 | `#1E9BD4` |
| 反白 White | `brand/white` | 深色底上的 mark | `#FFFFFF` |
| 墨 Ink | `brand/ink` | 横版文字主色 | `#1A1C2A` |

### 3.2 渐变
- **App 图标**：靛蓝主导的三段对角渐变 `#3F51B5 → #2E6FC0 → #1E9BD4`（前 60% 靛蓝，再过渡到偏蓝的青；方向左上 → 右下）。
- **横版 mark**：双拱沿**水平** `indigo → cyan` 渐变（左 indigo → 右 cyan）。
- 承接现有 UI 主题色 `ColorScheme.fromSeed(Colors.indigo)`，向青色延伸出科技／网络／连通的记忆点。

### 3.3 明暗与场景
- **彩色底 + 反白 mark**：默认形态（App 图标、深色场景）。
- **单色版**：仅 `#3F51B5`（浅底）或 `#FFFFFF`（深底）。
- 品牌色为固定值，**不随明暗模式反相**；浅／深背景通过切换「单色／反白」两套适配。
- 横版文字：通途＝`#3F51B5`，Tongtu＝近墨深灰，slogan＝中灰（弱化）。

### 3.4 App 主题配色（由品牌色推导）
Material 3 风格，明暗两套；已落地于 Figma `App Theme` 变量集合（Light / Dark 两 mode，17 token）与 `lib/ui/app_theme.dart`（接入 `main.dart`，`themeMode: system`）。核心 token：

| Token | Light | Dark |
|------|-------|------|
| primary | `#3F51B5` | `#BBC3FF` |
| secondary | `#1E9BD4` | `#8DD2F2` |
| surface | `#FFFFFF` | `#15161B` |
| background | `#F6F7FB` | `#0F1014` |
| error | `#BA1A1A` | `#FFB4AB` |

> 完整 17 个语义 token（含 on-* / container / outline）见 Figma `App Theme` 与 `app_theme.dart`。

### 3.5 设计变量（Design Tokens · 已落地 Figma）
采用 **Material 3 三层架构**：ref（原始）→ sys（语义）→ comp（组件）。

| 集合 | 层级 | 内容 |
|------|------|------|
| `Primitives` | ref | indigo/cyan/neutral/error 四组 tonal palette（35 色，scopes 隐藏）|
| `App Theme` | sys | 17 token × Light/Dark，alias Primitives（app UI 语义色）|
| `Brand Colors` | sys | logo 13 色，alias Primitives |
| `Spacing` | sys | 通用 scale（8–110）＋ 语义间距（clearspace 80、mark-gap 110、line-gap 24/16）|
| `Size` | sys | 字号（title 200 / pinyin 72 / slogan 50）＋ 关键尺寸（mark-height 360、app-icon 1024）|
| `Component` | comp | Icon / Mark / Lockup / Hero 各组件专属 token（33），alias sys |

- 引用链：**logo 节点 → Component（comp）→ sys（Brand Colors / Spacing / Size）→ Primitives（ref）**；改任一层级，下游全部联动更新。
- 组件（Lockup / Hero / Icon / Mark）的颜色（含渐变 stop）、间距（auto-layout padding/gap）、字号**全部引用 comp token**。
- Lockup 与 Hero 顶层均为 auto-layout `[mark, text]`（Hero 多 network absolute 背景），结构一致。
- 画布「Color Tokens」区展示主要品牌色板。

---

## 4. 标志组合（Lockups）

| 代号 | 组合 | 用途 |
|------|------|------|
| A · App 图标 | 渐变底板 + 反白双拱（方版／圆角版／圆形遮罩版） | iOS/iPadOS/macOS/Android 应用图标 |
| B · 横版锁定 | 渐变 mark ＋「通途」＋「Tongtu」＋ slogan | README、官网、关于页、文档头 |
| C · 纯 mark | 单色 / 反白双拱 | favicon、加载占位、超小标识、圆形遮罩 |

### 4.1 横版锁定（B）排布
- mark 在左；右侧自上而下：「通途」（Noto Sans SC Medium，主标）｜「Tongtu」（Inter，拼音，字距 +4）｜slogan「开源 · 跨平台代理」（Noto Sans SC，弱化色）。
- **mark 与三行文字组垂直居中**，mark 高度 ≈ 文字组总高；Tongtu／slogan 在「通途」下方、左缘对齐。
- **Lockup 与 Hero 用同一套规格**：字号 200／72／50，行距 24／16，mark 尺寸一致——仅背景不同（Lockup 透明＋渐变 mark，Hero 深底＋反白 mark＋网络）。
- mark 与文字间距 ≈ 110；slogan 为可选层，狭窄场景可省。

### 4.2 辅助视觉 · 网络 Hero（品牌延展）
深色横幅，以双拱 M 为枢纽、节点网络从其端点向外延展，营造「网络连接」氛围。用于官网 Hero、关于页、加载动画、文档头图、社交封面。
- **底**：深靛→深青对角渐变 `#1B1E40 → #0A2A33`（呼应主渐变「靛→青」走向）。
- **焦点**：双拱 M 反白（纯线、无端点）。
- **网络**：淡靛圆环（`#7E92E0`）＋ 青色实点（`#00BCD4`）＋ 淡白点 ＋ 淡连接线（`#6478C8`），作背景层，**不得盖过主 logo 与文字**。
- **铁律**：主 logo（双拱 M）始终是焦点；密集网络只作辅助／背景，**不可用作主 App 图标**（小尺寸糊、撞图，见 §1.2 取舍）。

---

## 5. 安全留白与最小尺寸

- **安全留白**：mark 四周预留 ≥ 单拱跨度（≈ mark 高度 × 0.5）的空白。
- **最小尺寸**：App 图标 ≥ 24 px 仍可辨双拱；< 24 px 用纯 mark 单色版。横版整体宽 ≥ 120 px，更窄去 slogan，再窄仅用 mark。
- **超小尺寸（≤16 px）**：可退化为单拱（牺牲 M 彩蛋，保连通语义）。

---

## 6. 单色 / 反白 / 圆形遮罩

- **单色版**：等比保留几何，颜色统一 `#3949AB`（浅底）或 `#FFFFFF`（深底）。
- **圆形遮罩**（Android 自适应圆形 / 旧 macOS）：mark 落在直径 80% 的圆形安全区内（已验证不被裁）。
- **Android 自适应图标**：前景＝反白 mark，背景＝主渐变；画布 108dp、安全区 66dp。

---

## 7. 误用规范（禁止）

1. ❌ 非等比拉伸 / 压扁 mark。
2. ❌ 改用非品牌色，或改变渐变方向／停止点。
3. ❌ 给 mark 加投影、外发光、描边、立体效果。
4. ❌ 旋转、镜像、拆解元素，或重新加回钥石／倒影等已移除装饰。
5. ❌ 在杂乱／低对比背景上直接放反白 mark（应先垫底板或改单色版）。
6. ❌ 替换「通途／Tongtu」的既定字形（Noto Sans SC Medium / Inter）后仍称为标准锁定。

---

## 8. 应用清单（多平台导出）

| 平台 | 形态要点 |
|------|----------|
| iOS / iPadOS | **1024×1024 满版方形、不透明、无 alpha、无圆角**；内容居中、避让四角约 10%。沿用现有 `AppIcon.appiconset` 全尺寸清单。 |
| macOS | 自带圆角矩形 + 周围透明留白（内容区约 824/1024）。 |
| Android | 自适应图标：前景／背景分层（见 §6）。 |
| Web / favicon | 纯 mark：`favicon.svg` + 16/32/48 PNG。 |
| 仓库 / 文档 | 横版锁定 SVG，置于 README 顶部、关于页。 |

---

## 9. 交付物与目录结构

Figma 源文件已建（见头部链接），含 App icons（方／圆角／圆形）、Horizontal lockup、Mark variants（单色／反白）。导出资产入库（矢量优先）：
```
assets/brand/
  tongtu-mark.svg            # 纯 mark（渐变）
  tongtu-mark-mono.svg       # 纯 mark（单色 #3949AB）
  tongtu-mark-white.svg      # 纯 mark（反白）
  tongtu-icon-1024.png       # App 图标满版方形
  tongtu-lockup.svg          # 横版锁定
  README.md                  # 用法与配色速查
ios/Runner/Assets.xcassets/AppIcon.appiconset/   # 替换现有占位全尺寸
```

---

## 10. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-17 | 初稿：确认「双孔拱桥／M」方向（弧桥连两端 → 拱券钥石倒影 → 融入 mihomo 的 M 双拱），定义几何、配色、组合、留白、多平台应用。 |
| v1.1 | 2026-06-17 | 定稿并在 Figma 落地：拱高定为 66（半椭圆弧，cubic bezier 近似）；**移除中墩钥石与水中倒影**（粗描边下钥石只露下半、易误读为下箭头，倒影削弱极简）；三落点外扩、端点加大、整体垂直居中；横版 mark 与「通途」等高同中线、采用水平渐变 + 端点衔接色；建立 Figma 变量集合与 App 图标／横版／单色反白变体；补 Figma 源文件链接。 |
| v1.2 | 2026-06-17 | 新增辅助视觉「网络 Hero」（双拱 M 为枢纽 + 节点网络延展，用于官网／关于页）；明确密集网络只作辅助、不作主图标（参考用户提供的网络连接图后的取舍）；Figma 中 mark 外层透明 frame 收紧为贴合 group。 |
| v1.3 | 2026-06-17 | mark 精简为纯双拱线（两个上半椭圆「双拼」，去除两端端点圆）；全套重新垂直居中。 |
| v1.4 | 2026-06-17 | 配色收敛为单一靛蓝 `#3F51B5`（删除多余的 `#3949AB` / `brand/indigo-deep`）：单色 mark、white-on-brand 卡底、横版主标统一为 `#3F51B5`。 |
| v1.5 | 2026-06-17 | 网络 Hero 深底渐变终点改为深青 `#0A2A33`（深靛→深青），呼应主渐变「靛→青」走向；横版 Lockup 加四周等量 clearspace。 |
| v1.6 | 2026-06-17 | Hero 文字统一为三行（同 Lockup）；新增 App 主题配色（Figma `App Theme` 变量 + `lib/ui/app_theme.dart`，明暗两套，已接入 `main.dart`）。 |
| v1.7 | 2026-06-17 | Lockup 与 Hero 统一为同一套排版：字号 200/72/50、行距 24/16、mark 高度≈文字组并与文字组垂直居中；横版 mark 渐变终点同步为蓝青 `#1E9BD4`。 |
| v1.8 | 2026-06-17 | 青色全面统一为偏蓝的 `#1E9BD4`（替换旧青绿 `#00BCD4`）：`brand/cyan` 变量、Hero 网络节点同步；App 图标确定为靛蓝主导三段渐变。 |
| v1.9 | 2026-06-17 | 品牌资产做成设计系统：Brand Colors 补至 13 色，新增 Spacing/Size 变量集合；logo 全套颜色（含渐变 stop）与字号绑定变量；圆形图标 mark 缩入安全区（占比~55%）；画布加 Color Tokens 色板。 |
| v1.10 | 2026-06-17 | 颜色升级为 Material 3 两层架构：新建 Primitives（35 色 tonal palette）作真相源，App Theme（17×2）与 Brand Colors（13）全部 alias 引用；单一真相源、全链联动。 |
| v1.11 | 2026-06-17 | Lockup 与 Hero 重构为嵌套 auto-layout；间距（clearspace 80、mark-gap 110、line-gap 24/16）真正绑定到 Spacing 变量，改变量布局联动更新。 |
| v1.12 | 2026-06-17 | Hero 改顶层 auto-layout（与 Lockup 同层级，network 设 absolute 背景）；补 comp（组件）层 Component 集合（33 token），所有 logo 节点颜色/间距/字号重绑到 comp，形成 Material 3 完整 ref→sys→comp 三层。 |
