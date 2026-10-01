import AppIntents
import CoreLocation
import Foundation
import WidgetKit

private let refreshWidgetKind = "WeatherCareWidget"
private let refreshWidgetGroup = "group.com.codesoha.weathercare"
private let refreshWidgetSnapshotKey = "snapshot"
private let refreshWidgetStatusKey = "refresh_status"
private let refreshWidgetURLKey = "refresh_url"
private let refreshWidgetGPSEnabledKey = "gps_enabled"

@available(iOS 17.0, *)
struct RefreshWeatherWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "날씨 새로고침"
  static var description = IntentDescription("앱을 열지 않고 위젯의 날씨를 새로고침합니다.")
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    await refreshWeatherWidget()
    return .result()
  }
}

@available(iOS 17.0, *)
private func refreshWeatherWidget() async {
  guard
    let defaults = UserDefaults(suiteName: refreshWidgetGroup),
    let rawURL = defaults.string(forKey: refreshWidgetURLKey),
    let savedURL = URL(string: rawURL)
  else { return }
  showWidgetRefreshStatus(defaults, "불러오는 중")
  let gpsEnabled = defaults.bool(forKey: refreshWidgetGPSEnabledKey)
  guard let url = await widgetRefreshURL(savedURL, gpsEnabled: gpsEnabled) else {
    if gpsEnabled { showWidgetLocationUnavailable(defaults) }
    return
  }
  guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
        url.host != nil else {
    showWidgetRefreshStatus(defaults, "서버 연결 실패")
    return
  }

  var request = URLRequest(
    url: url,
    cachePolicy: .reloadIgnoringLocalCacheData,
    timeoutInterval: 20
  )
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  guard
    let (data, response) = try? await URLSession.shared.data(for: request),
    let http = response as? HTTPURLResponse,
    (200..<300).contains(http.statusCode),
    data.count <= 512 * 1024,
    var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    object["schemaVersion"] as? Int == 3,
    object["region"] is String,
    object["refreshTime"] is String
  else {
    showWidgetRefreshStatus(defaults, "서버 연결 실패")
    return
  }

  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  object["receivedAt"] = formatter.string(from: Date())
  guard let stamped = try? JSONSerialization.data(withJSONObject: object),
        let rawSnapshot = String(data: stamped, encoding: .utf8) else {
    showWidgetRefreshStatus(defaults, "서버 연결 실패")
    return
  }

  let snapshot = gpsEnabled
    ? rawSnapshot
    : weatherWidgetSnapshotPreservingSpecificRegion(
      rawSnapshot,
      previous: defaults.string(forKey: refreshWidgetSnapshotKey)
    )
  defaults.set(snapshot, forKey: refreshWidgetSnapshotKey)
  defaults.removeObject(forKey: refreshWidgetStatusKey)
  if gpsEnabled { defaults.set(url.absoluteString, forKey: refreshWidgetURLKey) }
  WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
}

private func showWidgetLocationUnavailable(_ defaults: UserDefaults) {
  showWidgetRefreshStatus(defaults, "위치 확인 필요")
}

private func showWidgetRefreshStatus(_ defaults: UserDefaults, _ status: String) {
  defaults.set(status, forKey: refreshWidgetStatusKey)
  WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
}

@available(iOS 17.0, *)
private func widgetRefreshURL(_ savedURL: URL, gpsEnabled: Bool) async -> URL? {
  guard gpsEnabled else { return savedURL }
  let locationReader = await WidgetLocationReader()
  guard let location = await locationReader.locate(),
        let grid = widgetGrid(for: location.coordinate),
        var components = URLComponents(url: savedURL, resolvingAgainstBaseURL: false)
  else { return nil }

  var items = (components.queryItems ?? []).filter {
    !["nx", "ny", "latitude", "longitude", "regionCode", "regionName"].contains($0.name)
  }
  items.append(URLQueryItem(name: "nx", value: String(grid.nx)))
  items.append(URLQueryItem(name: "ny", value: String(grid.ny)))
  let resolvedName = await widgetRegionName(for: location)
  if let name = widgetPreferredRegionName(
    resolvedName, savedURL: savedURL, location: location, grid: grid
  ) {
    items.append(URLQueryItem(name: "regionName", value: name))
  }
  let precise = await MainActor.run {
    CLLocationManager().accuracyAuthorization == .fullAccuracy
  }
  if precise,
     location.horizontalAccuracy > 0,
     location.horizontalAccuracy <= 500 {
    items.append(URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)))
    items.append(URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)))
  }
  components.queryItems = items
  return components.url
}

@available(iOS 17.0, *)
@MainActor
private final class WidgetLocationReader: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var continuation: CheckedContinuation<CLLocation?, Never>?
  private var bestLocation: CLLocation?

  func locate() async -> CLLocation? {
    guard CLLocationManager.locationServicesEnabled(),
          manager.isAuthorizedForWidgetUpdates else { return nil }
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.delegate = self
    bestLocation = nil
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      manager.startUpdatingLocation()
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
        guard let self else { return }
        self.finish(self.bestLocation)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations where location.horizontalAccuracy > 0 &&
      Date().timeIntervalSince(location.timestamp) < 120 &&
      Date().timeIntervalSince(location.timestamp) > -60 {
      if bestLocation == nil || location.horizontalAccuracy < bestLocation!.horizontalAccuracy {
        bestLocation = location
      }
      if manager.accuracyAuthorization == .reducedAccuracy ||
          location.horizontalAccuracy <= 100 {
        finish(bestLocation)
        return
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(bestLocation)
  }

  private func finish(_ location: CLLocation?) {
    guard let continuation else { return }
    self.continuation = nil
    manager.stopUpdatingLocation()
    continuation.resume(returning: location)
  }
}

private func widgetGrid(for coordinate: CLLocationCoordinate2D) -> (nx: Int, ny: Int)? {
  let latitude = coordinate.latitude
  let longitude = coordinate.longitude
  guard (30...44).contains(latitude), (120...134).contains(longitude) else { return nil }
  let radians = Double.pi / 180
  let radius = 6371.00877 / 5.0
  let first = 30.0 * radians
  let second = 60.0 * radians
  let originLatitude = 38.0 * radians
  let originLongitude = 126.0 * radians
  let cone = log(cos(first) / cos(second)) /
    log(tan(.pi * 0.25 + second * 0.5) / tan(.pi * 0.25 + first * 0.5))
  let scale = pow(tan(.pi * 0.25 + first * 0.5), cone) * cos(first) / cone
  let originRadius = radius * scale / pow(tan(.pi * 0.25 + originLatitude * 0.5), cone)
  let targetRadius = radius * scale / pow(tan(.pi * 0.25 + latitude * radians * 0.5), cone)
  var angle = longitude * radians - originLongitude
  if angle > Double.pi { angle -= 2 * Double.pi }
  if angle < -Double.pi { angle += 2 * Double.pi }
  angle *= cone
  let nx = Int(floor(targetRadius * sin(angle) + 43.0 + 0.5))
  let ny = Int(floor(originRadius - targetRadius * cos(angle) + 136.0 + 0.5))
  return (1...149).contains(nx) && (1...253).contains(ny) ? (nx, ny) : nil
}

private func widgetRegionName(for location: CLLocation) async -> String? {
  let geocoder = CLGeocoder()
  guard let placemarks = try? await geocoder.reverseGeocodeLocation(
    location, preferredLocale: Locale(identifier: "ko_KR")
  ) else { return nil }
  var firstName: String?
  for placemark in placemarks where placemark.isoCountryCode == "KR" {
    guard let name = widgetDisplayRegionName(for: placemark) else { continue }
    if firstName == nil { firstName = name }
    if widgetNeighborhood(from: name) != nil { return name }
  }
  return firstName
}

private func widgetDisplayRegionName(for placemark: CLPlacemark) -> String? {
  let topLevel = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
  let metropolitan: [String: String] = [
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구",
    "인천광역시": "인천", "광주광역시": "광주", "대전광역시": "대전",
    "울산광역시": "울산", "세종특별자치시": "세종시",
  ]
  var parts: [String] = []
  if let topLevel, let shortName = metropolitan[topLevel] { parts.append(shortName) }
  for candidate in [placemark.locality, placemark.subAdministrativeArea, placemark.subLocality] {
    guard let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
          !name.isEmpty, name != topLevel, !parts.contains(name) else { continue }
    parts.append(name)
  }
  if !parts.contains(where: { widgetNeighborhood(from: $0) != nil }) {
    for candidate in [placemark.name, placemark.thoroughfare] {
      if let neighborhood = widgetNeighborhood(from: candidate), !parts.contains(neighborhood) {
        parts.append(neighborhood)
        break
      }
    }
  }
  if parts.isEmpty, let topLevel, !topLevel.isEmpty { parts.append(topLevel) }
  return parts.isEmpty ? nil : parts.joined(separator: " ")
}

private func widgetNeighborhood(from value: String?) -> String? {
  guard let value else { return nil }
  return value.split(whereSeparator: { $0.isWhitespace || ",()".contains($0) })
    .map(String.init)
    .first(where: { $0.hasSuffix("동") || $0.hasSuffix("읍") || $0.hasSuffix("면") })
}

private func widgetPreferredRegionName(
  _ resolved: String?, savedURL: URL, location: CLLocation, grid: (nx: Int, ny: Int)
) -> String? {
  guard let items = URLComponents(url: savedURL, resolvingAgainstBaseURL: false)?.queryItems,
        let stored = items.first(where: { $0.name == "regionName" })?.value,
        weatherWidgetRegionIsSpecific(stored),
        items.first(where: { $0.name == "nx" })?.value == String(grid.nx),
        items.first(where: { $0.name == "ny" })?.value == String(grid.ny),
        let latitude = Double(items.first(where: { $0.name == "latitude" })?.value ?? ""),
        let longitude = Double(items.first(where: { $0.name == "longitude" })?.value ?? ""),
        latitude.isFinite, longitude.isFinite,
        CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)),
        location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= 500
  else { return resolved }
  if let resolved, !resolved.isEmpty, !stored.hasPrefix(resolved + " ") {
    return resolved
  }
  return stored
}

func weatherWidgetSnapshotPreservingSpecificRegion(
  _ incoming: String,
  previous: String?
) -> String {
  guard
    let previous,
    let incomingData = incoming.data(using: .utf8),
    let previousData = previous.data(using: .utf8),
    var next = (try? JSONSerialization.jsonObject(with: incomingData)) as? [String: Any],
    let stored = (try? JSONSerialization.jsonObject(with: previousData)) as? [String: Any],
    let nextRegion = (next["region"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
    let storedRegion = (stored["region"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
    let nextLocation = weatherWidgetLocationScope(next["locationKey"] as? String),
    let storedLocation = weatherWidgetLocationScope(stored["locationKey"] as? String),
    weatherWidgetShouldPreserveRegion(nextRegion, stored: storedRegion),
    nextLocation == storedLocation
  else { return incoming }

  next["region"] = storedRegion
  guard
    let merged = try? JSONSerialization.data(withJSONObject: next),
    let snapshot = String(data: merged, encoding: .utf8)
  else { return incoming }
  return snapshot
}

private func weatherWidgetRegionIsSpecific(_ value: String?) -> Bool {
  guard let value, !value.isEmpty else { return false }
  return !["현재 위치", "선택 지역", "지역을 설정해주세요"].contains(value)
}

private func weatherWidgetShouldPreserveRegion(
  _ incoming: String?,
  stored: String?
) -> Bool {
  guard let stored, weatherWidgetRegionIsSpecific(stored) else { return false }
  guard let incoming, weatherWidgetRegionIsSpecific(incoming) else { return true }
  return stored.count > incoming.count && stored.hasPrefix(incoming)
}

private func weatherWidgetLocationScope(_ value: String?) -> String? {
  guard let key = value?.trimmingCharacters(in: .whitespacesAndNewlines),
        !key.isEmpty else { return nil }
  return key.components(separatedBy: ":name:").first
}
