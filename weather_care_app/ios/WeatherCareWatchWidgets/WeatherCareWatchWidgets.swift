import SwiftUI
import WidgetKit

private struct WeatherEntry: TimelineEntry {
  let date: Date
  let snapshot: WatchSnapshot
}

private struct WeatherProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: .now, snapshot: .empty) }
  func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
    completion(WeatherEntry(date: .now, snapshot: WatchCache.load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
    let snapshot = WatchCache.load(), now = Date()
    var dates = [now]
    if let end = snapshot.generatedAt?.addingTimeInterval(10_801), end > now { dates.append(end) }
    completion(Timeline(entries: dates.map { WeatherEntry(date: $0, snapshot: snapshot) }, policy: .after(now.addingTimeInterval(1800))))
  }
}

private struct WeatherAccessory: View {
  @Environment(\.widgetFamily) private var family
  let entry: WeatherEntry
  private var valid: Bool { entry.snapshot.hasData && !entry.snapshot.stale(at: entry.date) }
  private func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "SUITE-ExtraBold" : "SUITE-Regular", size: size, relativeTo: .caption)
  }
  var body: some View {
    Group {
      if !valid {
        VStack(spacing: 3) {
          Image(systemName: entry.snapshot.hasData ? "clock" : "iphone")
          Text(family == .accessoryCircular ? "—" : entry.snapshot.hasData ? "날씨 다시 확인" : "iPhone에서 날씨챙겨를 열어 주세요")
            .font(font(12)).multilineTextAlignment(.center)
        }
      } else if family == .accessoryCircular {
        VStack(spacing: 0) {
          WatchWeatherIcon(condition: entry.snapshot.condition, compact: true).frame(width: 23, height: 23)
          Text(compactTemperature).font(font(20, bold: true))
        }
      } else {
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .top) {
            Text(entry.snapshot.region).lineLimit(1)
            Spacer(minLength: 5)
            Text(entry.snapshot.time + " 기준").lineLimit(1).fixedSize()
          }.font(font(10))
          HStack(spacing: 6) {
            WatchWeatherIcon(condition: entry.snapshot.condition, compact: true).frame(width: 25, height: 25)
            Text(entry.snapshot.temperature).font(font(24, bold: true)).lineLimit(1).minimumScaleFactor(0.7)
            Text("체감 " + entry.snapshot.apparent).font(font(11)).lineLimit(1).minimumScaleFactor(0.8)
          }
          Text("최저 \(entry.snapshot.minimum) / 최고 \(entry.snapshot.maximum)").font(font(11)).lineLimit(1)
        }
      }
    }
    .containerBackground(.black, for: .widget)
    .widgetURL(URL(string: "weathercarewatch://current"))
  }
  private var compactTemperature: String {
    guard let value = Double(entry.snapshot.temperature.replacingOccurrences(of: "°", with: "")), value.isFinite else { return entry.snapshot.temperature }
    return "\(Int(value.rounded()))°"
  }
}

@main
struct WeatherCareWatchWidgets: Widget {
  let kind = "WeatherCareWatchWeather"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in WeatherAccessory(entry: entry) }
      .configurationDisplayName("날씨챙겨")
      .description("지역과 기준시각, 기온·체감, 최저·최고를 확인해요.")
      .supportedFamilies([.accessoryRectangular, .accessoryCircular])
  }
}
