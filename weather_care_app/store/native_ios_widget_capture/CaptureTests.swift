import XCTest

// 전용 시뮬레이터의 SpringBoard를 XCTest로 조작하고 원본 화면을 보존한다.
final class CaptureTests: XCTestCase {
  @MainActor
  func testCaptureWidgets() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("widget-capture", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    print("CAPTURE_ROOT=\(folder.path)")
    func save(_ name: String) throws {
      try springboard.debugDescription.write(to: folder.appendingPathComponent("state.txt"), atomically: true, encoding: .utf8)
      try XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
    try save("initial")
    try "ready".write(to: folder.appendingPathComponent("ready"), atomically: true, encoding: .utf8)
    // 재실행할 때 이전 촬영 세션의 마지막 명령을 반복하지 않는다.
    var lastID = (try? Data(contentsOf: folder.appendingPathComponent("command.json")))
      .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["id"] as? Int ?? -1
    let deadline = Date().addingTimeInterval(1800)
    while Date() < deadline {
      let commandURL = folder.appendingPathComponent("command.json")
      guard let data = try? Data(contentsOf: commandURL),
            let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = command["id"] as? Int, id != lastID else {
        Thread.sleep(forTimeInterval: 0.15)
        continue
      }
      lastID = id
      let action = command["action"] as? String ?? "dump"
      if action == "finish" { break }
      if action == "home" { XCUIDevice.shared.press(.home) }
      if let label = command["label"] as? String {
        let matches = springboard.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
        guard matches.firstMatch.waitForExistence(timeout: 3),
              let element = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
          try save(command["name"] as? String ?? "missing-element")
          try "요소 없음: \(label)".write(to: folder.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
          try String(id).write(to: folder.appendingPathComponent("done"), atomically: true, encoding: .utf8)
          continue
        }
        if action == "press" { element.press(forDuration: command["duration"] as? Double ?? 1.2) }
        else if action == "type" { element.tap(); element.typeText(command["text"] as? String ?? "") }
        else if action == "capture" {
          let name = command["name"] as? String ?? "widget"
          try element.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name)-element.png"))
        } else { element.tap() }
      } else if let x = command["x"] as? Double, let y = command["y"] as? Double {
        let point = springboard.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        if action == "press" { point.press(forDuration: 2) }
        else if action == "swipe", let dx = command["dx"] as? Double, let dy = command["dy"] as? Double {
          point.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)))
        } else { point.tap() }
      }
      Thread.sleep(forTimeInterval: command["wait"] as? Double ?? 1)
      try save(command["name"] as? String ?? "state")
      try String(id).write(to: folder.appendingPathComponent("done"), atomically: true, encoding: .utf8)
    }
  }
}
