import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testMovementChangesWidgetGridAndRemovesPreviousRegion() throws {
    let url = try XCTUnwrap(BackgroundLocationMonitor.widgetURL(
      previous: "https://example.com/api/v1/weather/widget?nx=60&ny=127&regionName=old&regionCode=old&widgetSettings=u1p1",
      registration: "https://example.com/api/v1/installations/test/location",
      latitude: 35.1796, longitude: 129.0756, precise: true))
    let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(values["nx"], "98")
    XCTAssertEqual(values["ny"], "76")
    XCTAssertEqual(values["latitude"], "35.1796")
    XCTAssertEqual(values["widgetSettings"], "u1p1")
    XCTAssertNil(values["regionName"])
    XCTAssertNil(values["regionCode"])
  }

  func testCoarseLocationAndServerGuards() throws {
    let previous = "https://example.com/api/v1/weather/widget"
    let url = try XCTUnwrap(BackgroundLocationMonitor.widgetURL(previous: previous,
      registration: "https://example.com/location", latitude: 33.4996, longitude: 126.5312, precise: false))
    XCTAssertEqual(url.query, "nx=53&ny=38")
    XCTAssertNil(BackgroundLocationMonitor.widgetURL(previous: previous,
      registration: "https://other.example/location", latitude: 37.57, longitude: 126.98, precise: true))
    XCTAssertNil(BackgroundLocationMonitor.gridFor(latitude: .nan, longitude: 126))
    XCTAssertNil(BackgroundLocationMonitor.gridFor(latitude: 0, longitude: 0))
    let seoul = try XCTUnwrap(BackgroundLocationMonitor.gridFor(latitude: 37.5665, longitude: 126.978))
    XCTAssertEqual(seoul.0, 60)
    XCTAssertEqual(seoul.1, 127)
  }

  func testResolvedKoreanRegionName() {
    XCTAssertEqual(BackgroundLocationMonitor.widgetRegionName(administrativeArea: "서울특별시",
      locality: "서울특별시", subAdministrativeArea: "중구", subLocality: "소공동"), "서울 중구 소공동")
    XCTAssertEqual(BackgroundLocationMonitor.widgetRegionName(administrativeArea: "경기도",
      locality: "시흥시", subAdministrativeArea: "시흥시", subLocality: "은행동"), "시흥시 은행동")
    XCTAssertNil(BackgroundLocationMonitor.widgetRegionName(administrativeArea: nil,
      locality: nil, subAdministrativeArea: nil, subLocality: nil))
  }

}
