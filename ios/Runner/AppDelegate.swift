import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let tunnel = TunnelController()
  private let ssidReader = WiFiSSIDReader()
  private var stateSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      let method = FlutterMethodChannel(name: "com.dingqi.tongtu/core", binaryMessenger: messenger)
      let event = FlutterEventChannel(name: "com.dingqi.tongtu/core_state", binaryMessenger: messenger)
      method.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
      event.setStreamHandler(self)
      tunnel.onState = { [weak self] state in
        self?.stateSink?(state)
      }
      tunnel.load {}
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      handleStart(call, result: result)
    case "stop":
      tunnel.stop()
      result(nil)
    case "updateOnDemand":
      handleUpdateOnDemand(call, result: result)
    case "currentSSID":
      handleCurrentSSID(result)
    case "memory":
      result(tunnel.memorySnapshot())
    case "lastResult":
      result(SharedStore.lastStartResult)
    case "logDir":
      // 返回 App Group 容器内日志目录绝对路径（主 App 用 dart:io 读取落盘日志）
      let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup)
      result(container?.appendingPathComponent("logs", isDirectory: true).path)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleStart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let config = args["config"] as? String,
          let port = args["port"] as? Int,
          let secret = args["secret"] as? String else {
      result(FlutterError(code: "bad_args", message: "缺少 config/port/secret", details: nil))
      return
    }
    tunnel.start(configYAML: config, port: port, secret: secret) { error in
      if let error = error {
        result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  private func handleUpdateOnDemand(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let config = OnDemandConfig.fromChannel(call.arguments as? [String: Any])
    tunnel.applyOnDemand(config) { error in
      if let error = error {
        result(
          FlutterError(
            code: "ondemand_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(nil)
      }
    }
  }

  private func handleCurrentSSID(_ result: @escaping FlutterResult) {
    ssidReader.current { res in
      switch res {
      case .success(let ssid):
        result(ssid)
      case .failure(let failure):
        result(
          FlutterError(
            code: failure.rawValue,
            message: "无法读取当前 Wi-Fi 名称",
            details: nil
          )
        )
      }
    }
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stateSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stateSink = nil
    return nil
  }
}

/// 主 App 侧隧道控制：经 NETunnelProviderManager 控制 PacketTunnel 扩展启停；
/// 启动前把运行时配置/端口/secret 写入 App Group 供扩展读取；状态经 onState 回调上报。
final class TunnelController {
  var onState: ((String) -> Void)?

  private var manager: NETunnelProviderManager?
  private var statusObserver: NSObjectProtocol?
  private let providerBundleId = "com.dingqi.tongtu.packet-tunnel"

  func load(completion: @escaping () -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
      guard let self = self else { completion(); return }
      self.manager = managers?.first ?? self.makeManager()
      self.observeStatus()
      self.emitState()
      completion()
    }
  }

  func start(configYAML: String, port: Int, secret: String, completion: @escaping (Error?) -> Void) {
    // config(YAML) 体积大，仍经 App Group 共享；端口/secret 改用 providerConfiguration
    // 随 VPN 配置可靠下发（避免 App Group UserDefaults 跨进程同步不及时导致端口不一致）。
    SharedStore.configYAML = configYAML

    let mgr = manager ?? makeManager()
    manager = mgr
    let proto = (mgr.protocolConfiguration as? NETunnelProviderProtocol)
      ?? NETunnelProviderProtocol()
    proto.providerBundleIdentifier = providerBundleId
    proto.serverAddress = "Tongtu"
    proto.providerConfiguration = ["port": port, "secret": secret]
    mgr.protocolConfiguration = proto
    mgr.isEnabled = true
    mgr.saveToPreferences { [weak self] error in
      if let error = error { completion(error); return }
      mgr.loadFromPreferences { error in
        if let error = error { completion(error); return }
        do {
          try mgr.connection.startVPNTunnel()
          self?.observeStatus()
          completion(nil)
        } catch {
          completion(error)
        }
      }
    }
  }

  func stop() {
    manager?.connection.stopVPNTunnel()
  }

  /// 写入按需连接规则并持久化（即时生效，无需重启隧道）。
  /// manager 不存在则创建并保留既有 protocolConfiguration；按需开启时启用 VPN 配置。
  /// 注：on-demand 自动连接复用上次 start 持久化的 providerConfiguration（端口/secret）
  /// 与 App Group 中的 configYAML，故首次使用前需至少手动连接一次（真机验证）。
  func applyOnDemand(_ config: OnDemandConfig, completion: @escaping (Error?) -> Void) {
    let mgr = manager ?? makeManager()
    manager = mgr
    mgr.onDemandRules = OnDemandRuleBuilder.build(config)
    mgr.isOnDemandEnabled = config.enabled
    if config.enabled {
      // 按需连接生效要求 VPN 配置处于启用态。
      mgr.isEnabled = true
    }
    mgr.saveToPreferences(completionHandler: completion)
  }

  /// 读取扩展经 App Group 上报的内存指标；无数据（未运行）返回 nil。
  /// footprint = phys_footprint（jetsam 红线判据），goHeap = 内核 Go 堆 HeapAlloc。
  func memorySnapshot() -> [String: Any]? {
    let footprint = SharedStore.physFootprintBytes
    guard footprint > 0 else { return nil }
    let age = Date().timeIntervalSince1970 - SharedStore.memoryStatsAt
    var goHeap = 0
    if let data = SharedStore.memoryStatsJSON.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let heap = obj["heapAlloc"] as? NSNumber {
      goHeap = heap.intValue
    }
    return ["footprint": footprint, "goHeap": goHeap, "age": age]
  }

  private func makeManager() -> NETunnelProviderManager {
    let mgr = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = providerBundleId
    proto.serverAddress = "Tongtu"
    mgr.protocolConfiguration = proto
    mgr.localizedDescription = "通途"
    return mgr
  }

  private func observeStatus() {
    guard let connection = manager?.connection else { return }
    if let observer = statusObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    statusObserver = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange, object: connection, queue: .main
    ) { [weak self] _ in
      self?.emitState()
    }
  }

  private func emitState() {
    let status = manager?.connection.status ?? .invalid
    onState?(Self.stateString(status))
  }

  private static func stateString(_ status: NEVPNStatus) -> String {
    switch status {
    case .connected:
      return "connected"
    case .connecting, .reasserting, .disconnecting:
      return "connecting"
    case .disconnected, .invalid:
      return "stopped"
    @unknown default:
      return "stopped"
    }
  }
}
