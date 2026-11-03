import Foundation
import WatchConnectivity
import os

/// iPhone이 선택한 지역의 최신 전체 상태만 전달한다. 인증 정보는 보내지 않는다.
final class WatchPhoneBridge: NSObject, WCSessionDelegate {
  static let shared = WatchPhoneBridge()
  var onRefresh: (() -> Void)?
  private let defaults = UserDefaults.standard
  private let logger = Logger(subsystem: "com.codesoha.weathercare", category: "WatchConnectivity")
  private var raw: String? { defaults.string(forKey: "watch_outgoing_snapshot") }

  func start() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func publish(snapshot: String, details: [String: Any]) {
    guard let data = snapshot.data(using: .utf8),
          let widget = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    save(widget: widget, details: details, cleared: false)
  }

  func clear() { save(widget: [:], details: [:], cleared: true) }

  private func save(widget: [String: Any], details: [String: Any], cleared: Bool) {
    let revision = max(Int64(Date().timeIntervalSince1970 * 1000), Int64(defaults.double(forKey: "watch_outgoing_revision")) + 1)
    let envelope: [String: Any] = ["schemaVersion": 1, "revision": revision,
      "publishedAt": Int64(Date().timeIntervalSince1970 * 1000), "widget": widget,
      "details": details, "cleared": cleared]
    guard let data = try? JSONSerialization.data(withJSONObject: envelope),
          let value = String(data: data, encoding: .utf8) else { return }
    defaults.set(Double(revision), forKey: "watch_outgoing_revision")
    defaults.set(value, forKey: "watch_outgoing_snapshot")
    sendLatest()
  }

  private func sendLatest() {
    let session = WCSession.default
    guard WCSession.isSupported(), session.activationState == .activated,
          session.isPaired, session.isWatchAppInstalled, let raw else { return }
    do {
      try session.updateApplicationContext(["snapshot": raw])
      if session.isReachable { session.sendMessage(["snapshot": raw], replyHandler: nil) { _ in } }
      logger.info("watch:sent revision=\(self.defaults.double(forKey: "watch_outgoing_revision"))")
    } catch { logger.error("watch:send_failed \((error as NSError).code)") }
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { self.sendLatest() }
  }
  func sessionWatchStateDidChange(_ session: WCSession) { DispatchQueue.main.async { self.sendLatest() } }
  func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { self.sendLatest() } }
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async {
      replyHandler(self.raw.map { ["snapshot": $0] } ?? [:])
      if message["request"] as? String == "refresh" { self.onRefresh?() }
    }
  }
}
