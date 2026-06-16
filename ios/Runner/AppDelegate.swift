import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let tunnel = TunnelController()
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
    case "stop":
      tunnel.stop()
      result(nil)
    case "memory":
      result(tunnel.memorySnapshot())
    default:
      result(FlutterMethodNotImplemented)
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
    // 注入运行时配置与控制器端口/secret 到 App Group，供扩展启动时读取
    SharedStore.configYAML = configYAML
    SharedStore.controllerPort = port
    SharedStore.controllerSecret = secret

    let mgr = manager ?? makeManager()
    manager = mgr
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
