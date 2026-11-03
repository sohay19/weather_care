import Foundation

struct WatchPreparation: Identifiable, Hashable {
  let id: String
  let label: String
  let reason: String
}

struct WatchMetric: Identifiable, Hashable {
  var id: String { name }
  let name: String
  let value: String
  let basis: String
  let description: String
}

struct WatchHour: Identifiable {
  var id: Date { at }
  let at: Date
  let label: String
  let temperature: String
  let condition: String
  let rain: String
}

/// Android와 같은 스냅샷 계약. 비밀키나 서버 접속 정보는 포함하지 않는다.
struct WatchSnapshot {
  static let group = "group.com.codesoha.weathercare.watch"
  let object: [String: Any]
  static let empty = WatchSnapshot(object: [:])
  var widget: [String: Any] { object["widget"] as? [String: Any] ?? [:] }
  var details: [String: Any] { object["details"] as? [String: Any] ?? [:] }
  var revision: Int64 { (object["revision"] as? NSNumber)?.int64Value ?? 0 }
  var cleared: Bool { object["cleared"] as? Bool ?? false }
  var hasData: Bool { !cleared && widget["currentTemperature"] != nil }
  var region: String { text(widget, "region", "iPhone 연결 필요") }
  var locationKey: String { text(widget, "locationKey", "none") }
  var generatedAt: Date? { Self.date(widget["generatedAt"] as? String) }
  var temperature: String { text(widget, "currentTemperature") }
  var apparent: String { text(widget, "apparentTemperature") }
  var minimum: String { text(widget, "minimumTemperature") }
  var maximum: String { text(widget, "maximumTemperature") }
  var condition: String { text(widget, "condition", "unknown") }
  var time: String { text(widget, "refreshTime", "기준 시각 없음").replacingOccurrences(of: " 기준", with: "") }
  var comparison: String { text(details, "temperatureComparison", "어제 비교 자료 없음") }
  var apparentComparison: String { text(details, "apparentComparison", "체감 비교 자료 없음") }

  static func parse(_ raw: String) -> WatchSnapshot? {
    guard let data = raw.data(using: .utf8), data.count <= 500_000,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          object["schemaVersion"] as? Int == 1 else { return nil }
    let snapshot = WatchSnapshot(object: object)
    guard snapshot.revision > 0 else { return nil }
    guard snapshot.cleared || snapshot.hasData && snapshot.generatedAt != nil && snapshot.locationKey != "none" else { return nil }
    return snapshot
  }

  func stale(at now: Date = Date()) -> Bool {
    guard let date = generatedAt else { return true }
    return date > now.addingTimeInterval(300) || now.timeIntervalSince(date) > 10_800
  }

  func preparations(at now: Date = Date()) -> [WatchPreparation] {
    guard !stale(at: now), hasData else { return [] }
    let timeline = widget["briefingTimeline"] as? [[String: Any]] ?? []
    let active = timeline.first { entry in
      guard let start = Self.date(entry["validFrom"] as? String),
            let end = Self.date(entry["validUntil"] as? String) else { return false }
      return start <= now && now < end
    }
    let catalog = widget["preparationCatalog"] as? [[String: Any]] ?? widget["preparations"] as? [[String: Any]] ?? []
    let selected: [[String: Any]]
    if let active {
      selected = (active["recommendedItems"] as? [String] ?? []).compactMap { type in
        catalog.first { $0["type"] as? String == type }
      }
    } else {
      guard timeline.isEmpty, let end = Self.date(widget["validUntil"] as? String), now < end else { return [] }
      selected = widget["preparations"] as? [[String: Any]] ?? []
    }
    let reasons = details["preparationReasons"] as? [String: String] ?? [:]
    var seen = Set<String>()
    return selected.compactMap { item in
      guard let type = item["type"] as? String, seen.insert(type).inserted else { return nil }
      return WatchPreparation(id: type, label: text(item, "label", "준비물"),
        reason: reasons[type].flatMap { $0.isEmpty ? nil : $0 } ?? "현재 브리핑에서 추천한 준비물이에요.")
    }
  }

  func hours(at now: Date = Date()) -> [WatchHour] {
    guard !stale(at: now), hasData else { return [] }
    return (details["hours"] as? [[String: Any]] ?? []).compactMap { item -> WatchHour? in
      guard let date = Self.date(item["at"] as? String), date > now else { return nil }
      return WatchHour(at: date, label: text(item, "label"), temperature: text(item, "temperature"),
        condition: text(item, "condition", "unknown"), rain: text(item, "rain"))
    }.sorted { $0.at < $1.at }.prefix(12).map { $0 }
  }

  var metrics: [WatchMetric] {
    let raw = details["metrics"] as? [[String: Any]] ?? []
    return Self.descriptions.map { name, description in
      let item = raw.first { $0["name"] as? String == name } ?? [:]
      return WatchMetric(name: name, value: text(item, "value", "자료 없음"),
        basis: Self.displayBasis(text(item, "basis", "기준 시각 없음")),
        description: text(item, "description", description))
    }
  }

  func checkKey(_ type: String, at date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd"
    return "\(locationKey)|\(formatter.string(from: date))|\(type)"
  }

  static func date(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  static func displayBasis(_ value: String) -> String {
    guard let date = date(value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date) + " 기준"
  }

  static let descriptions = [
    ("체감온도", "기온·바람·습도를 반영한 체감온도예요."),
    ("습도", "현재 상대습도예요. 낮으면 보습 준비물을 챙겨요."),
    ("자외선", "자료가 제공되는 시각의 자외선 지수예요."),
    ("바람", "현재 풍속과 풍향을 확인해요."),
    ("대기질", "미세먼지·초미세먼지 관측 자료예요."),
    ("대기정체", "대기 순환 예측 단계이며 미세먼지 농도와 달라요."),
    ("가시거리", "현재 수평 가시거리 관측 자료예요."),
    ("꽃가루", "제공 기간의 꽃가루 위험 예측이에요."),
    ("강수량", "최근 강수 관측이며 미래 강수확률과 달라요."),
    ("적설량", "현재 관측 적설이며 예보 신적설과 달라요.")
  ]

  private func text(_ dictionary: [String: Any], _ key: String, _ fallback: String = "—") -> String {
    guard let value = dictionary[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
    return value
  }
}

enum WatchCache {
  static var defaults: UserDefaults { UserDefaults(suiteName: WatchSnapshot.group) ?? .standard }
  static var raw: String? { defaults.string(forKey: "watch_snapshot") }
  static func load(storage: UserDefaults = defaults) -> WatchSnapshot {
    storage.string(forKey: "watch_snapshot").flatMap(WatchSnapshot.parse) ?? .empty
  }
  @discardableResult static func accept(_ raw: String, storage: UserDefaults = defaults) -> Bool {
    guard let next = WatchSnapshot.parse(raw), next.revision > load(storage: storage).revision else { return false }
    let previous = load(storage: storage)
    storage.set(raw, forKey: "watch_snapshot")
    if next.cleared || previous.locationKey != next.locationKey {
      // 다른 지역의 체크는 해당 키로 보존하지만 삭제 시에는 모두 지운다.
      if next.cleared { storage.removeObject(forKey: "preparation_checks") }
    }
    return true
  }
}
