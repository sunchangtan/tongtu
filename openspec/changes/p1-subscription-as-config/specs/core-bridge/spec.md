## ADDED Requirements

### Requirement: TUN 模式 DNS 覆写注入
core-bridge 在 TUN 模式（调用方注入 `tun-fd > 0`）下，应当（SHALL）确保生效 DNS 为 fake-ip 增强模式、补全 `fake-ip-filter`、设置 `tun.dns-hijack` 并启用 fake-ip 映射持久化，以保证 TUN 数据通路捕获的域名查询经 fake-ip 进入规则匹配与代理且重启不断连；若传入配置自带可用的 DNS 上游（`nameserver` 等）则应当（SHALL）保留之、仅强制注入 fake-ip 必需字段；非 TUN 模式下不得（MUST NOT）强制改写调用方/订阅自带的 DNS。

#### Scenario: 订阅自带 DNS 上游时保留并注入 fake-ip
- **当** 调用方以 `tun-fd > 0` 启动，且传入配置自带 `dns.enable=true` 与 `nameserver` 上游
- **则** 内核保留其 `nameserver` 等上游，强制 `enhanced-mode=fake-ip`、补全 `fake-ip-range` 与 `fake-ip-filter`，并设 `tun.dns-hijack`、启用 fake-ip 映射持久化

#### Scenario: 订阅无 DNS 时用默认 fake-ip DNS
- **当** 调用方以 `tun-fd > 0` 启动，且传入配置无 `dns` 段或未启用
- **则** 内核以默认 fake-ip DNS（含国内 DoH `nameserver`、`fake-ip-range`、`fake-ip-filter`）生效

#### Scenario: 非 TUN 模式不强制改写 DNS
- **当** 调用方未注入 `tun-fd`（非 TUN 模式）
- **则** 内核沿用传入配置自带的 DNS 设置，core-bridge 不强制覆写为 fake-ip

### Requirement: proxy-provider 本地缓存 path 注入
core-bridge 应当（SHALL）为传入配置中 `type: http` 的 proxy-providers 注入指向持久化 `home-dir` 的本地缓存 `path`，使内核将下载的 provider 内容落盘；当远程订阅源不可达且本地缓存存在时，内核应当（SHALL）回退使用本地缓存的节点，不因单次下载失败导致代理组为空。

#### Scenario: 注入缓存 path 并落盘
- **当** 传入配置含 `type: http` 的 proxy-provider
- **则** core-bridge 为其注入相对 `home-dir` 的本地缓存 path，内核下载内容落盘于 App Group 容器并跨启动持久

#### Scenario: 远程不可达时回退本地缓存
- **当** 重新启动时远程订阅源不可达，但本地缓存文件存在且可解析
- **则** 内核使用本地缓存的 provider 节点（首次无缓存除外），不因下载失败导致 0 节点
