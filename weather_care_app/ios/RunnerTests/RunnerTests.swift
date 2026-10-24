import Flutter
import CoreLocation
import Security
import UIKit
import XCTest
@testable import Runner

private final class SimulatorLocationProbe: NSObject, CLLocationManagerDelegate {
  let manager = CLLocationManager()
  var locations: [CLLocation] = []

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = false
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    self.locations.append(contentsOf: locations)
  }
}

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

  func testWidgetURLRejectsDifferentServerCredentialsAndEndpoint() {
    for previous in ["http://example.com/api/v1/weather/widget",
      "https://example.com:444/api/v1/weather/widget",
      "https://user@example.com/api/v1/weather/widget", "https://example.com/other"] {
      XCTAssertNil(BackgroundLocationMonitor.widgetURL(previous: previous,
        registration: "https://example.com/location", latitude: 37.5665,
        longitude: 126.978, precise: true))
    }
  }

  func testWidgetSettingsAndKoreanNameAreEncodedOnce() throws {
    let url = try XCTUnwrap(BackgroundLocationMonitor.widgetURL(
      previous: "https://example.com/api/v1/weather/widget?widgetSettings=a%2Bb&unknown=secret#old",
      registration: "https://example.com/location", latitude: 37.5665,
      longitude: 126.978, precise: false))
    var components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    components.queryItems?.append(URLQueryItem(name: "regionName", value: "서울 중구 소공동"))
    XCTAssertEqual(components.queryItems?.first { $0.name == "widgetSettings" }?.value, "a+b")
    XCTAssertEqual(components.queryItems?.last?.value, "서울 중구 소공동")
    XCTAssertFalse(url.absoluteString.contains("unknown"))
    XCTAssertNil(url.fragment)
  }

  func testWidgetRegionPreservesSpecificNameOnlyForSameGrid() throws {
    func snapshot(_ key: String, _ region: String) throws -> String {
      String(data: try JSONSerialization.data(withJSONObject:
        ["locationKey": key, "region": region]), encoding: .utf8)!
    }
    let previous = try snapshot("60:127:name:서울 중구 소공동", "서울 중구 소공동")
    for name in ["현재 위치", "서울 중구", "지역명 조회 중...", "지역명 조회 실패"] {
      let merged = weatherWidgetSnapshotPreservingSpecificRegion(
        try snapshot("60:127", name), previous: previous)
      let object = try JSONSerialization.jsonObject(with: Data(merged.utf8)) as! [String: String]
      XCTAssertEqual(object["region"], "서울 중구 소공동")
    }
    let moved = try snapshot("98:76", "부산")
    XCTAssertEqual(weatherWidgetSnapshotPreservingSpecificRegion(moved, previous: previous), moved)
    for name in ["지역명 조회 중...", "지역명 조회 실패"] {
      let failed = try snapshot("98:76", name)
      XCTAssertEqual(weatherWidgetSnapshotPreservingSpecificRegion(failed, previous: previous), failed)
      let recovered = try snapshot("98:76", "부산 중구 중앙동")
      XCTAssertEqual(weatherWidgetSnapshotPreservingSpecificRegion(recovered, previous: failed), recovered)
    }
  }

  @MainActor
  func testInvalidConfigurationDoesNotPersistCredentials() throws {
    let monitor = BackgroundLocationMonitor()
    defer { monitor.handle(FlutterMethodCall(methodName: "stop", arguments: nil)) { _ in } }
    for arguments: [String: Any] in [[:], ["url": "file:///tmp/test"],
      ["url": "https://example.com/location", "authorization": "Bearer invalid", "revision": UUID().uuidString],
      ["url": "https://example.com/location", "authorization": "Bearer " + String(repeating: "a", count: 64), "revision": "invalid"]] {
      var error: FlutterError?
      monitor.handle(FlutterMethodCall(methodName: "configure", arguments: arguments)) { error = $0 as? FlutterError }
      XCTAssertEqual(error?.code, "INVALID_CONFIGURATION")
    }
  }

  @MainActor
  func testStopDeletesKeychainAndDisablesMonitor() throws {
    let monitor = BackgroundLocationMonitor()
    let config: [String: Any] = ["url": "http://127.0.0.1:18787/location",
      "authorization": "Bearer " + String(repeating: "a", count: 64), "revision": UUID().uuidString]
    var error: FlutterError?
    monitor.handle(FlutterMethodCall(methodName: "configure", arguments: config)) { error = $0 as? FlutterError }
    XCTAssertNil(error, error?.code ?? "")
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.codesoha.weathercare.background-location",
      kSecAttrAccount as String: "configuration"]
    XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, nil), errSecSuccess)
    monitor.handle(FlutterMethodCall(methodName: "stop", arguments: nil)) { _ in }
    XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, nil), errSecItemNotFound)
    monitor.handle(FlutterMethodCall(methodName: "status", arguments: nil)) {
      XCTAssertEqual(($0 as? [String: Any])?["status"] as? String, "disabled")
    }
  }

  private let fixture = "http://127.0.0.1:18787"

  @MainActor
  private func control(_ query: String = "") async throws {
    let request = URLRequest(url: URL(string: fixture + "/control?" + query)!, timeoutInterval: 1)
    do { _ = try await URLSession.shared.data(for: request) }
    catch { throw XCTSkip("scripts/ios_parity_fixture.py 로컬 서버 실행 필요") }
    XCTAssertEqual(CLLocationManager().authorizationStatus, .authorizedAlways,
      "전용 시뮬레이터에 simctl privacy grant location-always 권한 설정 필요")
  }

  @MainActor
  private func configureMonitor(_ overrides: [String: Any] = [:]) throws -> BackgroundLocationMonitor {
    let monitor = BackgroundLocationMonitor()
    var config: [String: Any] = ["url": fixture + "/location",
      "authorization": "Bearer " + String(repeating: "a", count: 64),
      "revision": UUID().uuidString, "testAccessKey": "synthetic-must-not-leak"]
    config.merge(overrides) { _, new in new }
    var error: FlutterError?
    monitor.handle(FlutterMethodCall(methodName: "configure", arguments: config)) { error = $0 as? FlutterError }
    XCTAssertNil(error, error?.code ?? "")
    return monitor
  }

  private func storedConfiguration() throws -> [String: Any] {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.codesoha.weathercare.background-location",
      kSecAttrAccount as String: "configuration", kSecReturnData as String: true]
    var data: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &data)
    if status == errSecItemNotFound { return [:] }
    XCTAssertEqual(status, errSecSuccess)
    return try JSONSerialization.jsonObject(with: XCTUnwrap(data as? Data)) as! [String: Any]
  }

  @MainActor
  private func stop(_ monitor: BackgroundLocationMonitor) {
    monitor.handle(FlutterMethodCall(methodName: "stop", arguments: nil)) { _ in }
  }

  private func sample(latitude: Double = 35.1796, longitude: Double = 129.0756,
    accuracy: Double = 1000, age: TimeInterval = 0) -> CLLocation {
    CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
      timestamp: Date().addingTimeInterval(-age))
  }

  @MainActor
  private func waitUntil(_ predicate: () throws -> Bool) async throws {
    for _ in 0..<100 {
      if try predicate() { return }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("5초 안에 네이티브 처리가 완료되지 않음")
  }

  @MainActor
  func testNativeUploadAndWidgetFollowMovement() async throws {
    try await control()
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "group.com.codesoha.weathercare"))
    defaults.set(true, forKey: "gps_enabled")
    defaults.set(fixture + "/api/v1/weather/widget?nx=60&ny=127&regionName=old&widgetSettings=a%2Bb", forKey: "refresh_url")
    defaults.removeObject(forKey: "location_measured_at")
    let monitor = try configureMonitor()
    defer { stop(monitor); defaults.removePersistentDomain(forName: "group.com.codesoha.weathercare") }
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
    try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil &&
      self.storedConfiguration()["widgetPending"] == nil }
    let url = try XCTUnwrap(defaults.string(forKey: "refresh_url"))
    XCTAssertTrue(url.contains("nx=98&ny=76"))
    XCTAssertFalse(url.contains("latitude"))
    XCTAssertFalse(url.contains("regionName=old"))
    XCTAssertTrue(url.contains("widgetSettings=a%2Bb"))
    let snapshot = try XCTUnwrap(defaults.string(forKey: "snapshot"))
    let object = try JSONSerialization.jsonObject(with: Data(snapshot.utf8)) as! [String: Any]
    XCTAssertEqual(object["locationKey"] as? String, "98:76")
    XCTAssertEqual(object["currentTemperature"] as? String, "19°")
    XCTAssertEqual(object["region"] as? String, "검증 지역")
    XCTAssertNotNil(object["receivedAt"])
    let (data, _) = try await URLSession.shared.data(from: URL(string: fixture + "/state")!)
    let state = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let upload = try XCTUnwrap((state["requests"] as? [[String: Any]])?.first { $0["method"] as? String == "PUT" })
    XCTAssertEqual(upload["authorized"] as? Bool, true)
    XCTAssertEqual(upload["testKeyAbsent"] as? Bool, true)
    XCTAssertEqual(upload["contentType"] as? String, "application/json; charset=utf-8")
    XCTAssertEqual((upload["body"] as? [String: Any])?["precise"] as? Bool, false)
  }

  @MainActor
  func testInvalidAndOutdatedNativeSamplesNeverUpload() async throws {
    try await control()
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    for invalid in [sample(age: 901), sample(age: -61), sample(latitude: 35.7, longitude: 139.7),
      sample(latitude: .nan), sample(longitude: .infinity), sample(accuracy: 0),
      sample(accuracy: -1), sample(accuracy: 5001), sample(accuracy: .nan), sample(accuracy: .infinity)] {
      monitor.locationManager(CLLocationManager(), didUpdateLocations: [invalid])
      XCTAssertNil(try storedConfiguration()["pending"])
      XCTAssertNil(try storedConfiguration()["measuredAt"])
    }
    let (data, _) = try await URLSession.shared.data(from: URL(string: fixture + "/state")!)
    let state = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    XCTAssertEqual((state["requests"] as? [Any])?.count, 0)
  }

  @MainActor
  func testOfflineRetryAndOlderMeasurementCannotReplaceLatest() async throws {
    try await control("status=503")
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    let latest = sample()
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [latest])
    try await waitUntil { try self.storedConfiguration()["error"] as? Bool == true }
    let measured = try storedConfiguration()["measuredAt"] as? String
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample(age: 100), latest])
    XCTAssertEqual(try storedConfiguration()["measuredAt"] as? String, measured)
    XCTAssertNotNil(try storedConfiguration()["pending"])
    try await control()
    monitor.resume()
    try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil }
    XCTAssertNil(try storedConfiguration()["pending"])
    XCTAssertEqual(try storedConfiguration()["measuredAt"] as? String, measured)
  }

  @MainActor
  func testAuthenticationAndDeletedSessionStopMonitoring() async throws {
    for code in [401, 409, 410] {
      try await control("status=\(code)")
      let monitor = try configureMonitor()
      monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
      try await waitUntil { try self.storedConfiguration().isEmpty }
      stop(monitor)
    }
  }

  @MainActor
  func testManualSelectionAndNewerForegroundFixKeepWidget() async throws {
    for manual in [true, false] {
      try await control()
      let defaults = try XCTUnwrap(UserDefaults(suiteName: "group.com.codesoha.weathercare"))
      defaults.set(!manual, forKey: "gps_enabled")
      defaults.set(fixture + "/api/v1/weather/widget?nx=60&ny=127", forKey: "refresh_url")
      defaults.set("사용자가 선택한 자료", forKey: "snapshot")
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      defaults.set(formatter.string(from: Date().addingTimeInterval(30)), forKey: "location_measured_at")
      let monitor = try configureMonitor()
      monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
      try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil }
      XCTAssertEqual(defaults.string(forKey: "snapshot"), "사용자가 선택한 자료")
      XCTAssertNil(try storedConfiguration()["widgetPending"])
      stop(monitor)
      defaults.removePersistentDomain(forName: "group.com.codesoha.weathercare")
    }
  }

  @MainActor
  func testStopDuringUploadCannotRestoreConfiguration() async throws {
    try await control("delay=0.3")
    let monitor = try configureMonitor()
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
    stop(monitor)
    try await Task.sleep(nanoseconds: 500_000_000)
    XCTAssertTrue(try storedConfiguration().isEmpty)
  }

  @MainActor
  func testConfigurationSurvivesRecreationAndReinstallClearsConsent() async throws {
    try await control()
    let monitor = try configureMonitor()
    let revision = try storedConfiguration()["revision"] as? String
    let restored = BackgroundLocationMonitor()
    restored.handle(FlutterMethodCall(methodName: "status", arguments: nil)) {
      XCTAssertEqual(($0 as? [String: Any])?["status"] as? String, "active")
    }
    XCTAssertEqual(try storedConfiguration()["revision"] as? String, revision)
    let directory = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    try FileManager.default.removeItem(at: directory.appendingPathComponent("background-location-install"))
    let reinstalled = BackgroundLocationMonitor()
    XCTAssertTrue(try storedConfiguration().isEmpty)
    reinstalled.handle(FlutterMethodCall(methodName: "status", arguments: nil)) {
      XCTAssertEqual(($0 as? [String: Any])?["status"] as? String, "disabled")
    }
    stop(reinstalled); stop(restored); stop(monitor)
  }

  @MainActor
  func testExpiredPendingFixIsDiscardedOnResume() async throws {
    try await control()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let old = formatter.string(from: Date().addingTimeInterval(-901))
    let monitor = try configureMonitor(["measuredAt": old, "pending": [
      "measuredAt": old, "latitude": 35.1796, "longitude": 129.0756]])
    defer { stop(monitor) }
    XCTAssertNil(try storedConfiguration()["pending"])
    XCTAssertNil(try storedConfiguration()["syncedAt"])
  }

  @MainActor
  func testClientErrorDropsFixButRateLimitKeepsRetry() async throws {
    for code in [400, 429, 503] {
      try await control("status=\(code)")
      let monitor = try configureMonitor()
      monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
      try await waitUntil { try self.storedConfiguration()["error"] as? Bool == true }
      XCTAssertEqual(try storedConfiguration()["pending"] != nil, code != 400)
      stop(monitor)
    }
  }

  @MainActor
  func testOldSessionResponseCannotStopNewSession() async throws {
    try await control("status=401&delay=0.3")
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
    try await Task.sleep(nanoseconds: 50_000_000)
    try await control()
    let revision = UUID().uuidString
    monitor.handle(FlutterMethodCall(methodName: "configure", arguments: [
      "url": fixture + "/location", "authorization": "Bearer " + String(repeating: "a", count: 64),
      "revision": revision])) { XCTAssertNil($0 as? FlutterError) }
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
    try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil }
    try await Task.sleep(nanoseconds: 400_000_000)
    XCTAssertEqual(try storedConfiguration()["revision"] as? String, revision)
    XCTAssertNotNil(try storedConfiguration()["syncedAt"])
  }

  @MainActor
  func testDuplicateSubmillisecondSampleDoesNotUploadTwice() async throws {
    try await control()
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756),
      altitude: 0, horizontalAccuracy: 1000, verticalAccuracy: -1,
      timestamp: Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 0.123456))
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [location])
    try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil }
    monitor.locationManager(CLLocationManager(), didUpdateLocations: [location])
    try await Task.sleep(nanoseconds: 200_000_000)
    let (data, _) = try await URLSession.shared.data(from: URL(string: fixture + "/state")!)
    let state = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    XCTAssertEqual((state["requests"] as? [[String: Any]])?.filter { $0["method"] as? String == "PUT" }.count, 1)
  }

  @MainActor
  func testPermissionStateMatchesOSAndUnapprovedLocationIsNotStored() async throws {
    let permission = CLLocationManager().authorizationStatus
    print("위치 시험 환경: 권한=\(permission.rawValue), 백그라운드 새로고침=\(UIApplication.shared.backgroundRefreshStatus.rawValue)")
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    monitor.handle(FlutterMethodCall(methodName: "status", arguments: nil)) {
      XCTAssertEqual(($0 as? [String: Any])?["status"] as? String,
        permission == .authorizedAlways ? "active" : "permissionRequired")
    }
    if permission != .authorizedAlways {
      monitor.locationManager(CLLocationManager(), didUpdateLocations: [sample()])
      XCTAssertNil(try storedConfiguration()["pending"])
      XCTAssertNil(try storedConfiguration()["measuredAt"])
    }
  }

  @MainActor
  func testOSSignificantMovementDeliveryInBackground() async throws {
    executionTimeAllowance = 480
    try await control()
    guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
      throw XCTSkip("시뮬레이터가 significant-change 이동 감지를 지원하지 않아 실기기 검증 필요")
    }
    let (_, prepared) = try await URLSession.shared.data(from: URL(string: fixture + "/prepare-simulation")!)
    XCTAssertEqual((prepared as? HTTPURLResponse)?.statusCode, 200)
    let monitor = try configureMonitor()
    defer { stop(monitor) }
    try await waitUntil { try self.storedConfiguration()["syncedAt"] != nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let baseline = Date()
    let observation = UIApplication.shared.beginBackgroundTask(withName: "iOS 이동 콜백 시험")
    defer { if observation != .invalid { UIApplication.shared.endBackgroundTask(observation) } }
    let (_, simulation) = try await URLSession.shared.data(from: URL(string: fixture + "/simulate")!)
    XCTAssertEqual((simulation as? HTTPURLResponse)?.statusCode, 200)
    // 테스트 호스트만 홈으로 내린다. 제품 코드에는 private API를 사용하지 않는다.
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
    print("이동 시험 준비 완료: 서울 측정 전송 완료, 백그라운드 서울→부산 경로 시작")
    for _ in 0..<420 {
      let configuration = try storedConfiguration()
      guard !configuration.isEmpty else {
        XCTFail("다른 앱 초기화 또는 감시 인스턴스가 시험의 Keychain 설정을 삭제함. 전용 Dart 시험 진입점 필요")
        return
      }
      if let value = configuration["measuredAt"] as? String,
        let measured = formatter.date(from: value), measured > baseline.addingTimeInterval(0.8),
        configuration["syncedAt"] != nil {
        XCTAssertEqual(UIApplication.shared.applicationState, .background)
        let (data, _) = try await URLSession.shared.data(from: URL(string: fixture + "/state")!)
        let state = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let uploads = (state["requests"] as? [[String: Any]])?.filter { $0["method"] as? String == "PUT" } ?? []
        let body = try XCTUnwrap(uploads.last?["body"] as? [String: Any])
        let latitude = try XCTUnwrap(body["latitude"] as? Double)
        let longitude = try XCTUnwrap(body["longitude"] as? Double)
        let distance = CLLocation(latitude: latitude, longitude: longitude).distance(
          from: CLLocation(latitude: 37.5665, longitude: 126.978))
        if distance > 1000 {
          XCTAssertEqual((state["simulation"] as? [String: Any])?["routeStarted"] as? Bool, true)
          print("OS 백그라운드 이동 콜백·전송 확인: 서울에서 \(Int(distance))m 이동")
          return
        }
      }
      try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    XCTFail("서울 초기 OS 측정은 확인했으나 7분 이동 경로에서 새 significant-change 콜백을 받지 못함")
  }

  @MainActor
  func testSimulatorStandardLocationBackgroundControl() async throws {
    try await control()
    let (_, prepared) = try await URLSession.shared.data(from: URL(string: fixture + "/prepare-simulation")!)
    XCTAssertEqual((prepared as? HTTPURLResponse)?.statusCode, 200)
    let probe = SimulatorLocationProbe()
    probe.manager.startUpdatingLocation()
    defer { probe.manager.stopUpdatingLocation() }
    try await waitUntil { !probe.locations.isEmpty }
    let baseline = Date()
    let (_, simulation) = try await URLSession.shared.data(from: URL(string: fixture + "/simulate")!)
    XCTAssertEqual((simulation as? HTTPURLResponse)?.statusCode, 200)
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
    for _ in 0..<20 {
      if let location = probe.locations.last,
        location.timestamp > baseline.addingTimeInterval(0.8),
        location.distance(from: CLLocation(latitude: 37.5665, longitude: 126.978)) > 1000 {
        XCTAssertEqual(UIApplication.shared.applicationState, .background)
        print("대조 시험: 일반 CoreLocation OS 콜백으로 백그라운드 이동 좌표 수신, 직접 delegate 호출 없음")
        return
      }
      try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    XCTFail("일반 위치 서비스도 시뮬레이터 이동을 받지 못함")
  }

}
