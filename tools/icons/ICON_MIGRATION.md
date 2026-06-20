# Flutter 图标替换对照（Material → TongtuIcons）

把 Flutter 代码里的 Material 图标（`Icons.*`）替换成通途图标库（`TongtuIcons.*`，Lucide 子集 IconFont，与 Web `@tongtu/icons` / Figma `Icons/*` 同源）。

## 1. 用到图标的文件顶部加 import

```dart
import 'package:tongtu/ui/icons/tongtu_icons.g.dart';
```

## 2. 替换对照表（30 个）

| Material（旧） | TongtuIcons（新） |
|---|---|
| `Icons.add` | `TongtuIcons.plus` |
| `Icons.article_outlined` | `TongtuIcons.newspaper` |
| `Icons.balance` | `TongtuIcons.scale` |
| `Icons.brightness_auto` | `TongtuIcons.sunMoon` |
| `Icons.check_circle` | `TongtuIcons.circleCheck` |
| `Icons.chevron_right` | `TongtuIcons.chevronRight` |
| `Icons.cleaning_services_outlined` | `TongtuIcons.eraser` |
| `Icons.cloud_off_outlined` | `TongtuIcons.cloudOff` |
| `Icons.cloud_outlined` | `TongtuIcons.cloud` |
| `Icons.dark_mode` | `TongtuIcons.moon` |
| `Icons.delete_outline` | `TongtuIcons.trash2` |
| `Icons.description_outlined` | `TongtuIcons.fileText` |
| `Icons.info_outline` | `TongtuIcons.info` |
| `Icons.ios_share` | `TongtuIcons.share` |
| `Icons.light_mode` | `TongtuIcons.sun` |
| `Icons.memory` | `TongtuIcons.cpu` |
| `Icons.network_check` | `TongtuIcons.network` |
| `Icons.pause` | `TongtuIcons.pause` |
| `Icons.play_arrow` | `TongtuIcons.play` |
| `Icons.power_settings_new` | `TongtuIcons.power` |
| `Icons.public` | `TongtuIcons.globe` |
| `Icons.radio_button_checked` | `TongtuIcons.circleDot` |
| `Icons.radio_button_unchecked` | `TongtuIcons.circle` |
| `Icons.refresh` | `TongtuIcons.refreshCw` |
| `Icons.rule_outlined` | `TongtuIcons.listChecks` |
| `Icons.search` | `TongtuIcons.search` |
| `Icons.settings_outlined` | `TongtuIcons.settings` |
| `Icons.speed` | `TongtuIcons.gauge` |
| `Icons.tune` | `TongtuIcons.slidersHorizontal` |
| `Icons.wifi_find` | `TongtuIcons.wifi` |

> 替换涉及文件（截至生成时）：`home_shell` / `kernel_settings_page` / `settings_page` / `subscriptions_page` / `nodes_page` / `monitor_page` / `ondemand_page` / `rules_page` / `log_viewer_page` / `config_viewer_page` / `text_viewer_page`。

## 3. 替换后验证

```bash
fvm flutter analyze   # 第一方代码 0 警告
fvm flutter test      # 全量编译无破坏
fvm flutter run       # 模拟器看图标渲染正常
```

## 维护

- 图标库源：`tools/icons/icons.json`（清单：name / category / lucide / material / codepoint）+ `tools/icons/source/*.svg`（Lucide 原始 SVG）。
- 增删图标：改「源 + 清单」→ `node tools/icons/build.mjs`，Flutter 字体（`lib/ui/icons/`）/ Web（`@tongtu/icons`）/ 清单三端联动。
- 依赖：`tools/icons` 下 `npm install`（含 `lucide-static`）；字体子集化需 Python `fonttools`（`pip install fonttools`）。
