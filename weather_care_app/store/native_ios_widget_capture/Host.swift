import SwiftUI
import WidgetKit

@main
struct CaptureHost: App {
  init() {
    let snapshot: [String: Any] = [
      "schemaVersion": 3, "region": "서울시 중구", "refreshTime": "오전 8:00 기준",
      "condition": "partlyCloudy", "currentTemperature": "18°", "apparentTemperature": "17°",
      "minimumTemperature": "12°", "maximumTemperature": "22°",
      "shortMessage": "우산을 챙기세요",
      "brief": "아침에는 선선하고 저녁에는 비가 내려요.\n우산과 겉옷을 챙기세요.",
      "nextTime": "오전 9시", "nextCondition": "clear", "nextTemperature": "19°",
      "preparations": [["type": "UMBRELLA", "label": "우산"], ["type": "OUTERWEAR", "label": "겉옷"]]
    ]
    let defaults = UserDefaults(suiteName: "group.com.codesoha.weathercare")!
    let data = try! JSONSerialization.data(withJSONObject: snapshot)
    defaults.set(String(data: data, encoding: .utf8)!, forKey: "snapshot")
    defaults.removeObject(forKey: "refresh_url")
    defaults.removeObject(forKey: "refresh_status")
    defaults.synchronize()
    WidgetCenter.shared.reloadAllTimelines()
  }

  var body: some Scene {
    WindowGroup {
      VStack(spacing: 16) {
        Text("날씨챙겨 위젯 촬영").font(.title)
        Text("현재 위젯 확장과 촬영용 예시 날씨를 사용해요.")
      }.padding()
    }
  }
}
