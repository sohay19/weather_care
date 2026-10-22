import CoreLocation
import Flutter
import Security
import UIKit
import WidgetKit

/// Significant-change monitoring can relaunch the app without a Flutter screen.
final class BackgroundLocationMonitor: NSObject, CLLocationManagerDelegate, URLSessionTaskDelegate {
  private let manager = CLLocationManager()
  private let widgetGeocoder = CLGeocoder()
  private let service = "com.codesoha.weathercare.background-location"
  private var task: URLSessionDataTask?
  private var widgetTask: Task<Void, Never>?
  private var widgetTaskID: UUID?
  private var configuration: [String: Any]?
  private var storageFailed = false
  private let formatter = ISO8601DateFormatter()
  private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)

  override init() {
    super.init()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    // Keychain survives uninstall. A non-backed-up installation marker prevents
    // a reinstall from silently resuming a previous installation's consent.
    do {
      let directory = try FileManager.default.url(for: .applicationSupportDirectory,
        in: .userDomainMask, appropriateFor: nil, create: true)
      var marker = directory.appendingPathComponent("background-location-install")
      if !FileManager.default.fileExists(atPath: marker.path) {
        SecItemDelete(keyQuery as CFDictionary)
        try Data().write(to: marker, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try marker.setResourceValues(values)
      }
      var query = keyQuery
      query[kSecReturnData as String] = true
      query[kSecMatchLimit as String] = kSecMatchLimitOne
      var value: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &value)
      if status == errSecSuccess, let data = value as? Data {
        configuration = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      } else if status != errSecItemNotFound {
        storageFailed = true
      }
    } catch { storageFailed = true }
  }

  private var keyQuery: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service, kSecAttrAccount as String: "configuration"]
  }

  private func persist() throws {
    guard let configuration else { return }
    let data = try JSONSerialization.data(withJSONObject: configuration)
    let values: [String: Any] = [kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    var status = SecItemUpdate(keyQuery as CFDictionary, values as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(keyQuery.merging(values) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw NSError(domain: service, code: Int(status))
    }
    storageFailed = false
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let values = call.arguments as? [String: Any],
        let rawURL = values["url"] as? String, let url = URL(string: rawURL),
        validURL(url), let authorization = values["authorization"] as? String,
        authorization.range(of: "^Bearer [0-9a-f]{64}$", options: .regularExpression) != nil,
        let revision = values["revision"] as? String, UUID(uuidString: revision) != nil else {
        result(FlutterError(code: "INVALID_CONFIGURATION", message: "이동 감지 설정을 확인해주세요.", details: nil))
        return
      }
      task?.cancel()
      task = nil
      cancelWidgetRefresh()
      configuration = values
      do { try persist(); resume(); result(nil) }
      catch {
        configuration = nil
        manager.stopMonitoringSignificantLocationChanges()
        storageFailed = true
        result(FlutterError(code: "STORAGE_FAILED", message: "이동 감지 설정을 저장하지 못했어요.", details: nil))
      }
    case "stop": stop(); result(nil)
    case "resume": resume(); result(nil)
    case "requestPermission":
      let initial = (call.arguments as? [String: Any])?["initial"] as? Bool ?? false
      if manager.authorizationStatus == .authorizedAlways {
        resume()
      } else if manager.authorizationStatus == .authorizedWhenInUse &&
          !UserDefaults.standard.bool(forKey: "background-location-always-requested") {
        UserDefaults.standard.set(true, forKey: "background-location-always-requested")
        manager.requestAlwaysAuthorization()
      } else if !initial && manager.authorizationStatus == .notDetermined {
        manager.requestWhenInUseAuthorization()
      } else if !initial, let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "status": result(status())
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func validURL(_ url: URL) -> Bool {
    #if DEBUG
      return url.scheme == "https" || url.scheme == "http"
    #else
      return url.scheme == "https"
    #endif
  }

  func resume() {
    guard configuration != nil, !storageFailed,
      manager.authorizationStatus == .authorizedAlways,
      CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
    manager.startMonitoringSignificantLocationChanges()
    uploadLatest()
    refreshWidget()
  }

  private func stop() {
    cancelWidgetRefresh()
    configuration = nil
    task?.cancel()
    task = nil
    manager.stopMonitoringSignificantLocationChanges()
    let status = SecItemDelete(keyQuery as CFDictionary)
    storageFailed = status != errSecSuccess && status != errSecItemNotFound
  }

  private func status() -> [String: Any] {
    let state: String
    if storageFailed { state = "error" }
    else if configuration == nil { state = "disabled" }
    else if !CLLocationManager.significantLocationChangeMonitoringAvailable() { state = "unsupported" }
    else if !CLLocationManager.locationServicesEnabled() { state = "locationDisabled" }
    else if manager.authorizationStatus != .authorizedAlways { state = "permissionRequired" }
    else if configuration?["error"] as? Bool == true { state = "error" }
    else { state = "active" }
    var values: [String: Any] = ["status": state]
    values["measuredAt"] = configuration?["measuredAt"]
    values["syncedAt"] = configuration?["syncedAt"]
    return values
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedAlways { resume() }
    else {
      manager.stopMonitoringSignificantLocationChanges()
      task?.cancel()
      cancelWidgetRefresh()
      configuration?.removeValue(forKey: "widgetPending")
      configuration?.removeValue(forKey: "pending")
      try? persist()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard configuration != nil, manager.authorizationStatus == .authorizedAlways,
      let location = locations.max(by: { $0.timestamp < $1.timestamp }),
      location.horizontalAccuracy > 0, location.horizontalAccuracy <= 5000,
      location.coordinate.latitude.isFinite, location.coordinate.longitude.isFinite,
      (30...44).contains(location.coordinate.latitude), (120...134).contains(location.coordinate.longitude),
      Date().timeIntervalSince(location.timestamp) <= 15 * 60,
      Date().timeIntervalSince(location.timestamp) >= -60 else { return }
    let measuredAt = formatter.string(from: location.timestamp)
    if let previous = configuration?["measuredAt"] as? String,
      let date = formatter.date(from: previous),
      let measured = formatter.date(from: measuredAt), date >= measured { return }
    cancelWidgetRefresh()
    configuration?.removeValue(forKey: "widgetPending")
    let precise = manager.accuracyAuthorization == .fullAccuracy && location.horizontalAccuracy <= 500
    let revision = configuration?["revision"] ?? ""
    configuration?["pending"] = ["revision": revision,
      "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy, "precise": precise, "measuredAt": measuredAt]
    configuration?["measuredAt"] = measuredAt
    do { try persist(); uploadLatest() }
    catch { storageFailed = true; manager.stopMonitoringSignificantLocationChanges() }
  }

  private func uploadLatest() {
    guard task == nil, !storageFailed, manager.authorizationStatus == .authorizedAlways,
      let config = configuration, let pending = config["pending"] as? [String: Any],
      let measuredAt = pending["measuredAt"] as? String,
      let measured = formatter.date(from: measuredAt), let rawURL = config["url"] as? String,
      let url = URL(string: rawURL), validURL(url),
      let revision = config["revision"] as? String else { return }
    guard Date().timeIntervalSince(measured) <= 15 * 60 && Date().timeIntervalSince(measured) >= -60 else {
      configuration?.removeValue(forKey: "pending"); try? persist(); return
    }
    var request = URLRequest(url: url, timeoutInterval: 12)
    request.httpMethod = "PUT"
    request.setValue(config["authorization"] as? String, forHTTPHeaderField: "Authorization")
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    if url.host == "weather-test-api.codesoha.com" {
      request.setValue(config["testAccessKey"] as? String, forHTTPHeaderField: "X-Weather-Care-Test-Key")
    }
    request.httpBody = try? JSONSerialization.data(withJSONObject: pending)
    var backgroundID: UIBackgroundTaskIdentifier = .invalid
    var uploadTask: URLSessionDataTask?
    backgroundID = UIApplication.shared.beginBackgroundTask(withName: "이동 지역 갱신") {
      uploadTask?.cancel()
      if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID); backgroundID = .invalid }
    }
    uploadTask = session.dataTask(with: request) { [weak self] _, response, error in
      DispatchQueue.main.async {
        defer {
          if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID); backgroundID = .invalid }
        }
        guard let self, self.configuration?["revision"] as? String == revision else { return }
        self.task = nil
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if [401, 409, 410].contains(code) { self.stop(); return }
        let success = error == nil && (200..<300).contains(code)
        let discard = success || (400..<500).contains(code) && code != 429
        let latest = self.configuration?["pending"] as? [String: Any]
        if discard && latest?["measuredAt"] as? String == measuredAt {
          self.configuration?.removeValue(forKey: "pending")
        }
        self.configuration?["error"] = !success
        if success {
          self.configuration?["syncedAt"] = self.formatter.string(from: Date())
          if latest?["measuredAt"] as? String == measuredAt {
            self.configuration?["widgetPending"] = pending
          }
        }
        do { try self.persist() } catch { self.storageFailed = true }
        if latest?["measuredAt"] as? String != measuredAt { self.uploadLatest() }
        if success { self.refreshWidget() }
      }
    }
    task = uploadTask
    uploadTask?.resume()
  }

  private func cancelWidgetRefresh() {
    widgetGeocoder.cancelGeocode()
    widgetTask?.cancel()
    widgetTask = nil
    widgetTaskID = nil
  }

  private func refreshWidget() {
    guard widgetTask == nil, !storageFailed,
      manager.authorizationStatus == .authorizedAlways,
      let config = configuration, let pending = config["widgetPending"] as? [String: Any],
      let revision = config["revision"] as? String,
      let measuredAt = pending["measuredAt"] as? String,
      let measured = formatter.date(from: measuredAt),
      let latitude = pending["latitude"] as? Double, let longitude = pending["longitude"] as? Double,
      let defaults = UserDefaults(suiteName: "group.com.codesoha.weathercare") else { return }
    let stored = defaults.string(forKey: "location_measured_at").flatMap { formatter.date(from: $0) }
    // A manual selection or a newer foreground fix takes priority over a retry.
    guard defaults.bool(forKey: "gps_enabled"), stored == nil || measured >= stored! else {
      configuration?.removeValue(forKey: "widgetPending"); try? persist(); return
    }
    guard let previous = defaults.string(forKey: "refresh_url"),
      let registration = config["url"] as? String,
      let next = Self.widgetURL(previous: previous, registration: registration,
        latitude: latitude, longitude: longitude,
        precise: pending["precise"] as? Bool == true && (pending["accuracy"] as? Double ?? 5001) <= 500)
      else { return }
    defaults.set(next.absoluteString, forKey: "refresh_url")
    defaults.set(UUID().uuidString, forKey: "selection_revision")
    defaults.set(measuredAt, forKey: "location_measured_at")
    defaults.removeObject(forKey: "snapshot")
    defaults.set("불러오는 중", forKey: "refresh_status")
    WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
    let identifier = UUID()
    let selection = defaults.string(forKey: "selection_revision")
    widgetTaskID = identifier
    var backgroundID: UIBackgroundTaskIdentifier = .invalid
    backgroundID = UIApplication.shared.beginBackgroundTask(withName: "이동 위치 위젯 갱신") { [weak self] in
      if self?.widgetTaskID == identifier { self?.cancelWidgetRefresh() }
      if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID); backgroundID = .invalid }
    }
    widgetTask = Task { @MainActor [weak self] in
      defer {
        if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID) }
        if defaults.string(forKey: "selection_revision") != selection,
          self?.configuration?["revision"] as? String == revision,
          (self?.configuration?["widgetPending"] as? [String: Any])?["measuredAt"] as? String == measuredAt {
          self?.configuration?.removeValue(forKey: "widgetPending")
          try? self?.persist()
        }
        if self?.widgetTaskID == identifier {
          self?.widgetTask = nil
          self?.widgetTaskID = nil
        }
      }
      if pending["precise"] as? Bool == true,
        (pending["accuracy"] as? Double ?? 5001) <= 500, let self {
        let timeout = Task { @MainActor [weak self] in
          do { try await Task.sleep(nanoseconds: 4_000_000_000) } catch { return }
          if self?.widgetTaskID == identifier { self?.widgetGeocoder.cancelGeocode() }
        }
        let placemarks = try? await self.widgetGeocoder.reverseGeocodeLocation(
          CLLocation(latitude: latitude, longitude: longitude), preferredLocale: Locale(identifier: "ko_KR"))
        timeout.cancel()
        // Geocoding must not restore a GPS selection after a manual change/stop.
        if !Task.isCancelled, self.widgetTaskID == identifier,
          defaults.bool(forKey: "gps_enabled"),
          defaults.string(forKey: "selection_revision") == selection,
          defaults.string(forKey: "refresh_url") == next.absoluteString,
          let name = placemarks?.compactMap(Self.widgetRegionName).first,
          var named = URLComponents(url: next, resolvingAgainstBaseURL: false) {
          named.queryItems?.append(URLQueryItem(name: "regionName", value: name))
          if let url = named.url { defaults.set(url.absoluteString, forKey: "refresh_url") }
        }
      }
      guard !Task.isCancelled, self?.widgetTaskID == identifier,
        defaults.string(forKey: "selection_revision") == selection else { return }
      let success = await refreshWeatherWidget()
      guard let self, self.widgetTaskID == identifier else { return }
      self.widgetTask = nil
      self.widgetTaskID = nil
      if success, self.configuration?["revision"] as? String == revision,
        (self.configuration?["widgetPending"] as? [String: Any])?["measuredAt"] as? String == measuredAt {
        self.configuration?.removeValue(forKey: "widgetPending")
        try? self.persist()
      }
      // Failed requests retain only the latest pending fix for the next resume/movement.
    }
  }

  static func widgetRegionName(_ placemark: CLPlacemark) -> String? {
    guard placemark.isoCountryCode == "KR" else { return nil }
    return widgetRegionName(administrativeArea: placemark.administrativeArea,
      locality: placemark.locality, subAdministrativeArea: placemark.subAdministrativeArea,
      subLocality: placemark.subLocality)
  }

  static func widgetRegionName(administrativeArea: String?, locality: String?,
    subAdministrativeArea: String?, subLocality: String?) -> String? {
    let shortNames = ["서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구",
      "인천광역시": "인천", "광주광역시": "광주", "대전광역시": "대전",
      "울산광역시": "울산", "세종특별자치시": "세종시"]
    var parts: [String] = []
    if let top = administrativeArea, let short = shortNames[top] { parts.append(short) }
    for value in [locality, subAdministrativeArea, subLocality] {
      guard let name = value?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
        name != administrativeArea, !parts.contains(name) else { continue }
      parts.append(name)
    }
    if parts.isEmpty, let top = administrativeArea, !top.isEmpty { parts.append(top) }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
  }

  static func widgetURL(previous: String, registration: String,
    latitude: Double, longitude: Double, precise: Bool) -> URL? {
    guard let grid = gridFor(latitude: latitude, longitude: longitude),
      var url = URLComponents(string: previous), let server = URLComponents(string: registration),
      let host = url.host, host == server.host, url.scheme == server.scheme, url.port == server.port,
      ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil,
      url.path == "/api/v1/weather/widget" else { return nil }
    let settings = url.queryItems?.first { $0.name == "widgetSettings" }
    url.queryItems = [URLQueryItem(name: "nx", value: String(grid.0)),
      URLQueryItem(name: "ny", value: String(grid.1))]
    if let settings { url.queryItems?.append(settings) }
    if precise {
      url.queryItems?.append(URLQueryItem(name: "latitude", value: String(latitude)))
      url.queryItems?.append(URLQueryItem(name: "longitude", value: String(longitude)))
    }
    url.fragment = nil
    // URLSearchParams 서버가 '+'를 공백으로 해석하지 않도록 보존한다.
    url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return url.url
  }

  static func gridFor(latitude: Double, longitude: Double) -> (Int, Int)? {
    guard latitude.isFinite, longitude.isFinite,
      (30...44).contains(latitude), (120...134).contains(longitude) else { return nil }
    let rad = Double.pi / 180, radius = 6371.00877 / 5
    let first = 30 * rad, second = 60 * rad
    let cone = log(cos(first) / cos(second)) /
      log(tan(Double.pi / 4 + second / 2) / tan(Double.pi / 4 + first / 2))
    let scale = pow(tan(Double.pi / 4 + first / 2), cone) * cos(first) / cone
    let origin = radius * scale / pow(tan(Double.pi / 4 + 38 * rad / 2), cone)
    let target = radius * scale / pow(tan(Double.pi / 4 + latitude * rad / 2), cone)
    let angle = (longitude - 126) * rad * cone
    let nx = Int(floor(target * sin(angle) + 43.5))
    let ny = Int(floor(origin - target * cos(angle) + 136.5))
    return (1...149).contains(nx) && (1...253).contains(ny) ? (nx, ny) : nil
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void) {
    // Never forward installation credentials or a location body to a redirect.
    completionHandler(nil)
  }
}
