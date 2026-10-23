import XCTest

// 실제 설치된 제품 앱의 UI와 서버 자료를 그대로 촬영한다. 예시 자료를 주입하지 않는다.
final class AppCaptureTests: XCTestCase {
  @MainActor
  func testCaptureApp() throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.codesoha.weathercare")
    app.launch()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("app-capture", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func save(_ name: String) throws {
      try (app.debugDescription + "\nSYSTEM\n" + springboard.debugDescription)
        .write(to: folder.appendingPathComponent("state.txt"), atomically: true, encoding: .utf8)
      try XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
    try save("initial")
    try "ready".write(to: folder.appendingPathComponent("ready"), atomically: true, encoding: .utf8)
    var lastID = (try? Data(contentsOf: folder.appendingPathComponent("command.json")))
      .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["id"] as? Int ?? -1
    let deadline = Date().addingTimeInterval(3600)
    while Date() < deadline {
      guard let data = try? Data(contentsOf: folder.appendingPathComponent("command.json")),
            let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = command["id"] as? Int, id != lastID else {
        Thread.sleep(forTimeInterval: 0.15)
        continue
      }
      lastID = id
      let action = command["action"] as? String ?? "dump"
      if action == "finish" { break }
      let target = command["system"] as? Bool == true ? springboard : app
      if action == "launch" { app.launch() }
      if action == "activate" { app.activate() }
      if action == "home" { XCUIDevice.shared.press(.home) }
      if let label = command["label"] as? String {
        let matches = target.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        guard matches.firstMatch.waitForExistence(timeout: 3),
              let element = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
          try save(command["name"] as? String ?? "missing")
          try "요소 없음: \(label)".write(to: folder.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
          try String(id).write(to: folder.appendingPathComponent("done"), atomically: true, encoding: .utf8)
          continue
        }
        if action == "type" { element.tap(); element.typeText(command["text"] as? String ?? "") }
        else if action == "press" { element.press(forDuration: 1.2) }
        else { element.tap() }
      } else if let x = command["x"] as? Double, let y = command["y"] as? Double {
        let point = target.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        if action == "swipe", let dx = command["dx"] as? Double, let dy = command["dy"] as? Double {
          point.press(forDuration: 0.2,
                      thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)),
                      withVelocity: .slow, thenHoldForDuration: 0.5)
        } else if action == "press" { point.press(forDuration: 1.2) }
        else { point.tap() }
      }
      Thread.sleep(forTimeInterval: command["wait"] as? Double ?? 1)
      try save(command["name"] as? String ?? "state")
      try String(id).write(to: folder.appendingPathComponent("done"), atomically: true, encoding: .utf8)
    }
  }
}
