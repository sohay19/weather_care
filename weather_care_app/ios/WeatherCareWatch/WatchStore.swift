import SwiftUI
import WatchConnectivity
import WidgetKit
import os

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var snapshot = WatchCache.load()
  @Published private(set) var status = ""
  @Published private var checks = WatchCache.defaults.dictionary(forKey: "preparation_checks") as? [String: Bool] ?? [:]
  private let logger = Logger(subsystem: "com.codesoha.weathercare.watchkitapp", category: "WatchConnectivity")

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func checked(_ item: WatchPreparation) -> Bool { checks[snapshot.checkKey(item.id)] ?? false }
  func toggle(_ item: WatchPreparation) {
    let key = snapshot.checkKey(item.id)
    checks[key] = !(checks[key] ?? false)
    // 장기간 쌓인 날짜별 체크를 제한한다.
    if checks.count > 400 { checks = checks.filter { $0.key.hasPrefix(snapshot.locationKey + "|") } }
    WatchCache.defaults.set(checks, forKey: "preparation_checks")
  }

  func refresh() {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      status = "iPhone 연결 시 갱신"
      return
    }
    status = "iPhone에 갱신 요청 중"
    session.sendMessage(["request": "refresh"], replyHandler: { reply in
      DispatchQueue.main.async { self.receive(reply); self.status = "iPhone 연결됨" }
    }, errorHandler: { _ in DispatchQueue.main.async { self.status = "iPhone 연결 시 갱신" } })
  }

  private func receive(_ message: [String: Any]) {
    guard let raw = message["snapshot"] as? String, WatchCache.accept(raw) else { return }
    snapshot = WatchCache.load()
    if snapshot.cleared { checks = [:] }
    status = "iPhone에서 수신"
    WidgetCenter.shared.reloadAllTimelines()
    logger.info("watch:received revision=\(self.snapshot.revision)")
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { self.receive(session.receivedApplicationContext); self.refresh() }
  }
  func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { self.refresh() } }
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    DispatchQueue.main.async { self.receive(applicationContext) }
  }
  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    DispatchQueue.main.async { self.receive(message) }
  }
}
