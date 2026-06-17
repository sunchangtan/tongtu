/// 应用与内核版本号（静态常量，避免引入 package_info_plus / 经内核运行才能取）。
///
/// - [kAppVersion] 与 `pubspec.yaml` 的 version 同步；
/// - [kMihomoVersion] 与 `core-bridge/go.mod` 锁定的 mihomo release tag 同步。
/// 改版本时一并更新此处。
library;

const String kAppVersion = '1.0.0';
const String kMihomoVersion = 'v1.19.27';
