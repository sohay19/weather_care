import XCTest
@testable import WeatherCareWatchModel

final class WatchSnapshotTests: XCTestCase {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  func payload(_ revision: Int, cleared: Bool = false, age: TimeInterval = 0, expired: Bool = false, region: String = "60:127", resets: [String: String] = [:]) throws -> String {
    let iso = ISO8601DateFormatter()
    let widget: [String: Any] = ["locationKey": region, "region": "서울 중구 소공동", "generatedAt": iso.string(from: now.addingTimeInterval(-age)),
      "currentTemperature": "0°", "refreshTime": "10:00", "validUntil": iso.string(from: now.addingTimeInterval(expired ? -1 : 3600)),
      "preparations": [["type": "UMBRELLA", "label": "우산"]]]
    let object: [String: Any] = ["schemaVersion": 1, "revision": revision, "cleared": cleared, "widget": widget, "checkResetTokens": resets,
      "details": ["metrics": [["name": "습도", "value": "0%", "basis": "관측 시각"]]]]
    return String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
  }
  func testFreshnessBoundariesAndFutureClock() throws {
    XCTAssertFalse(try XCTUnwrap(WatchSnapshot.parse(payload(1, age: 10800))).stale(at: now))
    XCTAssertTrue(try XCTUnwrap(WatchSnapshot.parse(payload(1, age: 10801))).stale(at: now))
    XCTAssertTrue(try XCTUnwrap(WatchSnapshot.parse(payload(1, age: -301))).stale(at: now))
  }
  func testExpiredAndOldRecommendationsAreHidden() throws {
    XCTAssertEqual(try XCTUnwrap(WatchSnapshot.parse(payload(1))).preparations(at: now).count, 1)
    XCTAssertTrue(try XCTUnwrap(WatchSnapshot.parse(payload(1, expired: true))).preparations(at: now).isEmpty)
    XCTAssertTrue(try XCTUnwrap(WatchSnapshot.parse(payload(1, age: 10801))).preparations(at: now).isEmpty)
  }
  func testZeroAndMissingMetricsStayDistinct() throws {
    let snapshot = try XCTUnwrap(WatchSnapshot.parse(payload(1)))
    XCTAssertEqual(snapshot.metrics.count, 10)
    XCTAssertEqual(snapshot.metrics.first { $0.name == "습도" }?.value, "0%")
    XCTAssertEqual(snapshot.metrics.first { $0.name == "바람" }?.value, "자료 없음")
    XCTAssertEqual(snapshot.metrics.first { $0.name == "습도" }?.basis, "관측 시각")
  }
  func testDeletionBlocksDelayedOldSnapshotAndClearsChecks() throws {
    let name = "WeatherCareWatchTests." + UUID().uuidString
    let storage = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { storage.removePersistentDomain(forName: name) }
    XCTAssertTrue(try WatchCache.accept(payload(10), storage: storage))
    storage.set(["old": true], forKey: "preparation_checks")
    XCTAssertTrue(try WatchCache.accept(payload(12, cleared: true, resets: ["*": "delete-all"]), storage: storage))
    XCTAssertFalse(try WatchCache.accept(payload(11), storage: storage))
    XCTAssertFalse(WatchCache.load(storage: storage).hasData)
    XCTAssertNil(storage.object(forKey: "preparation_checks"))
    XCTAssertFalse(WatchCache.accept("{}", storage: storage))
  }
  func testChecklistSeparatesRegionAndKoreanDate() throws {
    let a = try XCTUnwrap(WatchSnapshot.parse(payload(1)))
    let b = try XCTUnwrap(WatchSnapshot.parse(payload(2, region: "61:128")))
    XCTAssertNotEqual(a.checkKey("UMBRELLA", at: now), b.checkKey("UMBRELLA", at: now))
    XCTAssertNotEqual(a.checkKey("UMBRELLA", at: now), a.checkKey("UMBRELLA", at: now.addingTimeInterval(86400)))
  }

  func testRegionRoundTripAndTemporaryClearPreserveChecks() throws {
    let name = "WeatherCareWatchTests." + UUID().uuidString
    let storage = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { storage.removePersistentDomain(forName: name) }
    let a = try XCTUnwrap(WatchSnapshot.parse(payload(1)))
    let key = a.checkKey("UMBRELLA", at: now)
    XCTAssertTrue(try WatchCache.accept(payload(1), storage: storage))
    storage.set([key: true], forKey: "preparation_checks")
    XCTAssertTrue(try WatchCache.accept(payload(2, cleared: true), storage: storage))
    XCTAssertFalse(WatchCache.load(storage: storage).hasData)
    XCTAssertFalse(try WatchCache.accept(payload(1), storage: storage))
    XCTAssertTrue(try WatchCache.accept(payload(3, region: "61:128"), storage: storage))
    XCTAssertFalse(WatchCache.load(storage: storage).checkKey("UMBRELLA", at: now) == key)
    XCTAssertTrue(try WatchCache.accept(payload(4), storage: storage))
    XCTAssertEqual(storage.dictionary(forKey: "preparation_checks") as? [String: Bool], [key: true])
  }

  func testCoalescedRegionDeletionOnlyClearsThatRegionOnce() throws {
    let name = "WeatherCareWatchTests." + UUID().uuidString
    let storage = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { storage.removePersistentDomain(forName: name) }
    XCTAssertTrue(try WatchCache.accept(payload(1), storage: storage))
    let a = "60:127|2026-11-03|UMBRELLA", b = "61:128|2026-11-03|SUNSCREEN"
    storage.set([a: true, b: true], forKey: "preparation_checks")
    // 중간 삭제 전송을 받지 못해도 다음 전체 날씨의 토큰으로 처리한다.
    let resets = ["60:127": "delete-a"]
    XCTAssertTrue(try WatchCache.accept(payload(3, region: "61:128", resets: resets), storage: storage))
    XCTAssertEqual(storage.dictionary(forKey: "preparation_checks") as? [String: Bool], [b: true])
    storage.set([a: true, b: true], forKey: "preparation_checks")
    XCTAssertTrue(try WatchCache.accept(payload(4, resets: resets), storage: storage))
    XCTAssertEqual(storage.dictionary(forKey: "preparation_checks") as? [String: Bool], [a: true, b: true])
    XCTAssertTrue(try WatchCache.accept(payload(5, resets: ["*": "delete-all"]), storage: storage))
    XCTAssertNil(storage.object(forKey: "preparation_checks"))
    storage.set([a: true], forKey: "preparation_checks")
    XCTAssertTrue(try WatchCache.accept(payload(6, resets: ["*": "delete-all"]), storage: storage))
    XCTAssertEqual(storage.dictionary(forKey: "preparation_checks") as? [String: Bool], [a: true])
  }
}
