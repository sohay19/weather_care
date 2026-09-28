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
    let snapshot = String(data: data, encoding: .utf8)
  else { return }

  defaults.set(snapshot, forKey: refreshWidgetSnapshotKey)
  WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
}
