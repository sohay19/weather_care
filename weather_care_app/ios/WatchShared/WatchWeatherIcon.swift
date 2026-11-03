import SwiftUI

/// 기존 Flutter/Android 날씨 아이콘 렌더 결과와 같은 PNG 자산을 사용한다.
struct WatchWeatherIcon: View {
  let condition: String
  var compact = false
  private var asset: String {
    let map = ["partlyCloudy": "partly_cloudy", "lightWintryMix": "light_wintry_mix", "wintryMix": "wintry_mix", "snowFlurry": "snow_flurry"]
    let name = map[condition] ?? condition
    return ["clear", "partly_cloudy", "overcast", "drizzle", "rain", "shower", "light_wintry_mix", "wintry_mix", "snow_flurry", "snow"].contains(name) ? name : "unknown"
  }
  var body: some View {
    Image("weather_" + asset + (compact ? "_accessory" : "")).resizable().scaledToFit()
      .accessibilityLabel(["clear": "맑음", "overcast": "흐림", "rain": "비", "snow": "눈"][condition] ?? "날씨 " + condition)
  }
}
