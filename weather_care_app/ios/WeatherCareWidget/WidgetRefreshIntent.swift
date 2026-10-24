import AppIntents
import Foundation
import WidgetKit

private let refreshWidgetKind = "WeatherCareWidget"
private let refreshWidgetGroup = "group.com.codesoha.weathercare"
private let refreshWidgetSnapshotKey = "snapshot"
private let refreshWidgetStatusKey = "refresh_status"
private let refreshWidgetURLKey = "refresh_url"
private let refreshWidgetRevisionKey = "selection_revision"
private let refreshWidgetTestAccessKey = "test_access_key"
private let refreshWidgetOperationKey = "refresh_operation"

private final class WidgetRefreshSessionDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
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

@MainActor
@discardableResult
func refreshWeatherWidget() async -> Bool {
  guard
    let defaults = UserDefaults(suiteName: refreshWidgetGroup),
    let rawURL = defaults.string(forKey: refreshWidgetURLKey),
    let url = URL(string: rawURL)
  else { return false }
  let revision = defaults.string(forKey: refreshWidgetRevisionKey)
  let operation = UUID().uuidString
  defaults.set(operation, forKey: refreshWidgetOperationKey)
  var latestWeather: [String: Any]?
  func isCurrentSelection() -> Bool {
    defaults.string(forKey: refreshWidgetRevisionKey) == revision &&
      defaults.string(forKey: refreshWidgetURLKey) == rawURL &&
      defaults.string(forKey: refreshWidgetOperationKey) == operation
  }
  func showStatus(_ status: String) {
    guard !Task.isCancelled, isCurrentSelection() else { return }
    defaults.set(status, forKey: refreshWidgetStatusKey)
    WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
  }
  defer {
    // 취소되거나 중단된 조회가 영구적으로 조회 중으로 남지 않게 한다.
    if isCurrentSelection(), let status = defaults.string(forKey: refreshWidgetStatusKey),
       ["불러오는 중", "지역명 조회 중..."].contains(status) {
      defaults.set(latestWeather == nil ? "서버 연결 실패" : "지역명 조회 실패",
                   forKey: refreshWidgetStatusKey)
      WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
    }
  }
  // GPS를 다시 측정하지 않고 앱에서 선택한 구역의 URL을 그대로 조회한다.
  guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
        url.host != nil else {
    showStatus("서버 연결 실패")
    return false
  }
  showStatus("불러오는 중")
  var request = URLRequest(
    url: url,
    cachePolicy: .reloadIgnoringLocalCacheData,
    timeoutInterval: 20
  )
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  if url.scheme == "https", url.host == "weather-test-api.codesoha.com",
     let key = defaults.string(forKey: refreshWidgetTestAccessKey), !key.isEmpty {
    request.setValue(key, forHTTPHeaderField: "X-Weather-Care-Test-Key")
  }
  let session = request.value(forHTTPHeaderField: "X-Weather-Care-Test-Key") == nil
    ? URLSession.shared
    : URLSession(configuration: .ephemeral,
        delegate: WidgetRefreshSessionDelegate(), delegateQueue: nil)
  defer {
    if session !== URLSession.shared { session.invalidateAndCancel() }
  }
  // 최초 조회 이후 지역명을 얻지 못하면 최대 5회 더 조회한다.
  for attempt in 0...5 {
    guard !Task.isCancelled, isCurrentSelection() else { return false }
    if attempt > 0 {
      do { try await Task.sleep(nanoseconds: 1_000_000_000) }
      catch { return false }
      guard !Task.isCancelled, isCurrentSelection() else { return false }
    }
    if let (data, response) = try? await session.data(for: request),
       let http = response as? HTTPURLResponse,
       (200..<300).contains(http.statusCode),
       data.count <= 512 * 1024,
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       object["schemaVersion"] as? Int == 3,
       object["region"] is String,
       object["refreshTime"] is String {
      var received = object
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      received["receivedAt"] = formatter.string(from: Date())
      latestWeather = received
    }
    // 구역 전환/삭제/앱 갱신 전의 응답과 오류는 새 선택을 덮어쓰지 않는다.
    guard !Task.isCancelled, isCurrentSelection() else { return false }
    guard let object = latestWeather else {
      if attempt == 5 { showStatus("서버 연결 실패") }
      continue
    }
    guard let stamped = try? JSONSerialization.data(withJSONObject: object),
          let rawSnapshot = String(data: stamped, encoding: .utf8) else {
      showStatus("서버 연결 실패")
      return false
    }
    let preserved = weatherWidgetSnapshotPreservingSpecificRegion(
      rawSnapshot,
      previous: defaults.string(forKey: refreshWidgetSnapshotKey)
    )
    guard let preservedData = preserved.data(using: .utf8),
          var next = try? JSONSerialization.jsonObject(with: preservedData) as? [String: Any]
    else { return false }
    let resolved = weatherWidgetRegionIsSpecific(next["region"] as? String)
    if !resolved {
      next["region"] = attempt < 5 ? "지역명 조회 중..." : "지역명 조회 실패"
    }
    guard let encoded = try? JSONSerialization.data(withJSONObject: next),
          let snapshot = String(data: encoded, encoding: .utf8) else { return false }
    guard !Task.isCancelled, isCurrentSelection() else { return false }
    defaults.set(snapshot, forKey: refreshWidgetSnapshotKey)
    if !resolved && attempt < 5 {
      defaults.set("지역명 조회 중...", forKey: refreshWidgetStatusKey)
    } else {
      defaults.removeObject(forKey: refreshWidgetStatusKey)
    }
    WidgetCenter.shared.reloadTimelines(ofKind: refreshWidgetKind)
    if resolved { return true }
  }
  return false
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
  guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty else { return false }
  return !["현재 위치", "선택 지역", "선택한 지역", "지역을 설정해주세요",
           "지역명 조회 중...", "지역명 조회 실패"].contains(value)
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
