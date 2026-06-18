import Foundation

/// geo 预置包安装器（p1-geo-mrs-conversion）：把随 app 打包的 BundleMRS.7z 拷到 App Group 容器
/// （= 内核 home-dir）根目录，供 PacketTunnel 扩展启动时 mihomo 经 rule-provider 的 path-in-bundle
/// 从中按需取 geo mrs，实现 geo 规则首连零网络必达（mihomo 官方 BundleMRS 机制）。
/// 由主 App 在启动时调用（扩展启动前就位）。
enum GeoBundleInstaller {
    /// 预置包文件名（须与内核 `C.Path.BundleMRS()` 约定的 `BundleMRS.7z` 一致）。
    static let bundleFileName = "BundleMRS.7z"
    private static let versionKey = "geoBundleVersion"

    /// 是否需要（重新）安装：未安装、或已装标识与当前预置包标识（字节大小）不一致。
    /// 纯函数，便于单测。
    static func shouldInstall(installed: Bool, installedVersion: String?, currentVersion: String) -> Bool {
        !installed || installedVersion != currentVersion
    }

    /// 确保预置包就位（幂等）。无 App Group 容器或包内无资源时静默跳过（不阻断启动）。
    /// 应在主 App 启动时**同步**调用：未变更时仅 stat + 读 UserDefaults 秒回，仅首次/更新时拷 4.5MB，
    /// 在界面显示前完成，确保扩展启动时包已就位（首连零网络必达），且远低于启动 watchdog。
    static func ensureInstalled() {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup),
            let src = Bundle.main.url(forResource: "BundleMRS", withExtension: "7z") else {
            return
        }
        let dest = container.appendingPathComponent(bundleFileName)
        let defaults = UserDefaults(suiteName: SharedStore.appGroup)
        // 版本判据用预置包字节大小：随 geo 数据更新而变，与 app 版本解耦（重打包即更新）
        let srcSize = (try? src.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let current = srcSize.map(String.init) ?? ""
        let installed = FileManager.default.fileExists(atPath: dest.path)
        guard shouldInstall(
            installed: installed,
            installedVersion: defaults?.string(forKey: versionKey),
            currentVersion: current
        ) else { return }

        // 原子安装：先拷临时文件，再原子替换/移动到目标，避免中途失败留下「缺失」或「半截损坏」的包。
        let tmp = container.appendingPathComponent(bundleFileName + ".tmp")
        do {
            try? FileManager.default.removeItem(at: tmp)
            try FileManager.default.copyItem(at: src, to: tmp)
            if installed {
                _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: dest)
            }
            defaults?.set(current, forKey: versionKey)
        } catch {
            // 失败不阻断启动（保留旧包）：内核 rule-provider 退化为远程拉取（首连分流可能不准）。
            try? FileManager.default.removeItem(at: tmp)
            NSLog("geo 预置包安装失败: %@", error.localizedDescription)
        }
    }
}
