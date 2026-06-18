import CoreLocation
import NetworkExtension

/// 读取当前连接的 Wi-Fi SSID。
///
/// iOS 13+ 读取 SSID 需定位授权：未决时请求 When-In-Use，授权后经
/// `NEHotspotNetwork.fetchCurrent` 取 SSID。授权被拒或未连 Wi-Fi 时回调失败。
final class WiFiSSIDReader: NSObject, CLLocationManagerDelegate {
  /// 读取失败原因（与 Dart 侧约定的错误码字符串一致）。
  enum Failure: String, Error {
    /// 定位权限被拒或受限。
    case denied
    /// 已授权但无法获取（未连 Wi-Fi 等）。
    case unavailable
  }

  private let locationManager = CLLocationManager()
  private var pending: ((Result<String, Failure>) -> Void)?

  /// 读取当前 SSID；定位权限未决时先请求 When-In-Use 授权。
  func current(completion: @escaping (Result<String, Failure>) -> Void) {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      fetch(completion)
    case .notDetermined:
      pending = completion
      locationManager.delegate = self
      locationManager.requestWhenInUseAuthorization()
    default:
      completion(.failure(.denied))
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let completion = pending else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      pending = nil
      fetch(completion)
    case .denied, .restricted:
      pending = nil
      completion(.failure(.denied))
    default:
      break // .notDetermined：等待用户在系统弹窗中决定
    }
  }

  private func fetch(_ completion: @escaping (Result<String, Failure>) -> Void) {
    NEHotspotNetwork.fetchCurrent { network in
      if let ssid = network?.ssid {
        completion(.success(ssid))
      } else {
        completion(.failure(.unavailable))
      }
    }
  }
}
