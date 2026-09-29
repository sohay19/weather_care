import AppIntents
import Foundation
import WidgetKit

private let refreshWidgetKind = "WeatherCareWidget"
private let refreshWidgetGroup = "group.com.codesoha.weathercare"
private let refreshWidgetSnapshotKey = "snapshot"
private let refreshWidgetURLKey = "refresh_url"

func weatherWidgetRefreshAvailable() -> Bool {
  guard let defaults = UserDefaults(suiteName: refreshWidgetGroup) else {
    return false
  }
  return !(defaults.string(forKey: refreshWidgetURLKey) ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .isEmpty
}

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
    let url = URL(string: rawURL),
    ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
    url.host != nil
  else { return }

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
    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    object["schemaVersion"] as? Int == 3,
    object["region"] is String,
    object["refreshTime"] is String,
    let rawSnapshot = String(data: data, encoding: .utf8)
  else { return }

  let snapshot = weatherWidgetSnapshotPreservingSpecificRegion(
    rawSnapshot,
    previous: defaults.string(forKey: refreshWidgetSnapshotKey)
  )
  defaults.set(snapshot, forKey: refreshWidgetSnapshotKey)
  WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
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
