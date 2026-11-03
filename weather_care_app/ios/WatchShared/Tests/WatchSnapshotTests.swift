import XCTest
@testable import WeatherCareWatchModel

final class WatchSnapshotTests: XCTestCase {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  func payload(_ revision: Int, cleared: Bool = false, age: TimeInterval = 0, expired: Bool = false, region: String = "60:127") throws -> String {
    let iso = ISO8601DateFormatter()
    let widget: [String: Any] = ["locationKey": region, "region": "서울 중구 소공동", "generatedAt": iso.string(from: now.addingTimeInterval(-age)),
      "currentTemperature": "0°", "refreshTime": "10:00", "validUntil": iso.string(from: now.addingTimeInterval(expired ? -1 : 3600)),
      "preparations": [["type": "UMBRELLA", "label": "우산"]]]
    let object: [String: Any] = ["schemaVersion": 1, "revision": revision, "cleared": cleared, "widget": widget,
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
    XCTAssertTrue(try WatchCache.accept(payload(12, cleared: true), storage: storage))
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
}
