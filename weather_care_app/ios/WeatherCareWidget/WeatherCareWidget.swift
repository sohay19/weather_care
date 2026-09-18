import Foundation
import SwiftUI
import WidgetKit

private let widgetKind = "WeatherCareWidget"
private let appGroup = "group.com.codesoha.weathercare"
private let snapshotKey = "snapshot"
private let ink = Color(red: 37 / 255, green: 55 / 255, blue: 78 / 255)
private let secondaryInk = Color(red: 96 / 255, green: 117 / 255, blue: 138 / 255)
private let surface = Color(red: 221 / 255, green: 236 / 255, blue: 247 / 255)

struct WeatherCareEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct WeatherCareProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeatherCareEntry {
    WeatherCareEntry(date: Date(), snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (WeatherCareEntry) -> Void) {
    completion(WeatherCareEntry(date: Date(), snapshot: WidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherCareEntry>) -> Void) {
    let now = Date()
    let entry = WeatherCareEntry(date: now, snapshot: WidgetSnapshot.load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct WidgetPreparation: Codable, Hashable {
  let type: String
  let label: String
}

struct WidgetSnapshot: Codable {
  let region: String
  let refreshTime: String
  let condition: String
  let currentTemperature: String
  let apparentTemperature: String
  let minimumTemperature: String
  let maximumTemperature: String
  let shortMessage: String
  let brief: String
  let nextTime: String
  let nextCondition: String
  let nextTemperature: String
  let preparations: [WidgetPreparation]

  static let placeholder = WidgetSnapshot(
    region: "시흥시 은행동",
    refreshTime: "오전 8:20 기준",
    condition: "partlyCloudy",
    currentTemperature: "18°",
    apparentTemperature: "18°",
    minimumTemperature: "12°",
    maximumTemperature: "20°",
    shortMessage: "겉옷 챙겨요",
    brief: "오전에는 선선하고 오후에는 포근해요. 얇은 겉옷을 챙기면 좋아요.",
    nextTime: "오전 9시",
    nextCondition: "clear",
    nextTemperature: "19°",
    preparations: [
      WidgetPreparation(type: "UMBRELLA", label: "우산"),
      WidgetPreparation(type: "OUTERWEAR", label: "겉옷"),
      WidgetPreparation(type: "MASK", label: "마스크")
    ]
  )

  static let empty = WidgetSnapshot(
    region: "지역을 설정해주세요",
    refreshTime: "앱에서 갱신",
    condition: "unknown",
    currentTemperature: "--°",
    apparentTemperature: "--°",
    minimumTemperature: "--°",
    maximumTemperature: "--°",
    shortMessage: "날씨챙겨를 열어 최신 날씨를 확인하세요",
    brief: "날씨챙겨를 열어 최신 날씨를 확인하세요.",
    nextTime: "예보 준비 중",
    nextCondition: "unknown",
    nextTemperature: "--°",
    preparations: []
  )

  static func load() -> WidgetSnapshot {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      let raw = defaults.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8),
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    else {
      return .empty
    }
    return snapshot
  }
}

struct WeatherCareWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: WeatherCareEntry

  var body: some View {
    Group {
      switch family {
      case .systemSmall:
        SmallWeatherWidget(snapshot: entry.snapshot)
      case .systemMedium:
        MediumWeatherWidget(snapshot: entry.snapshot)
      default:
        LargeWeatherWidget(snapshot: entry.snapshot)
      }
    }
    .widgetURL(URL(string: "weathercare://home"))
    .weatherWidgetBackground()
  }
}

private struct WidgetHeader: View {
  let snapshot: WidgetSnapshot
  let regionSize: CGFloat
  let timeSize: CGFloat

  var body: some View {
    HStack(spacing: 6) {
      Text(snapshot.region)
        .font(.system(size: regionSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Spacer(minLength: 2)
      Text(snapshot.refreshTime)
        .font(.system(size: timeSize, weight: .regular))
        .foregroundStyle(secondaryInk)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .foregroundStyle(ink)
  }
}

private struct MinMaxRow: View {
  let snapshot: WidgetSnapshot
  let size: CGFloat

  var body: some View {
    HStack(spacing: 4) {
      Text("최저")
      Text(snapshot.minimumTemperature).fontWeight(.bold)
      Text("  최고")
      Text(snapshot.maximumTemperature).fontWeight(.bold)
    }
    .font(.system(size: size))
    .foregroundStyle(ink.opacity(0.82))
    .lineLimit(1)
    .minimumScaleFactor(0.75)
  }
}

private struct SmallWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 4) {
      WidgetHeader(snapshot: snapshot, regionSize: 12, timeSize: 9)
      HStack(spacing: 3) {
        WeatherIconView(condition: snapshot.condition)
          .frame(width: 62, height: 62)
        Text(snapshot.currentTemperature)
          .font(.system(size: 38, weight: .regular))
          .foregroundStyle(ink)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .frame(maxHeight: .infinity)
      MinMaxRow(snapshot: snapshot, size: 13)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .widgetInfoPanel()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}

private struct MediumWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 3) {
      WidgetHeader(snapshot: snapshot, regionSize: 13, timeSize: 10)
      HStack(spacing: 10) {
        WeatherIconView(condition: snapshot.condition)
          .frame(width: 58, height: 58)
        Text(snapshot.currentTemperature)
          .font(.system(size: 34, weight: .regular))
        Divider().frame(height: 36).overlay(Color(red: 171 / 255, green: 195 / 255, blue: 214 / 255))
        VStack(spacing: -1) {
          Text("체감")
            .font(.system(size: 10))
            .foregroundStyle(secondaryInk)
          Text(snapshot.apparentTemperature)
            .font(.system(size: 34, weight: .regular))
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(ink)
      .frame(maxHeight: .infinity)
      HStack(spacing: 8) {
        Text(snapshot.shortMessage)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Spacer(minLength: 2)
        MinMaxRow(snapshot: snapshot, size: 12)
      }
      .foregroundStyle(ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .widgetInfoPanel()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
  }
}

private struct LargeWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 5) {
      WidgetHeader(snapshot: snapshot, regionSize: 14, timeSize: 11)
      HStack(spacing: 10) {
        WeatherIconView(condition: snapshot.condition)
          .frame(width: 72, height: 72)
        Text(snapshot.currentTemperature)
          .font(.system(size: 38, weight: .regular))
        Divider().frame(height: 40).overlay(Color(red: 171 / 255, green: 195 / 255, blue: 214 / 255))
        VStack(spacing: -1) {
          Text("체감")
            .font(.system(size: 11))
            .foregroundStyle(secondaryInk)
          Text(snapshot.apparentTemperature)
            .font(.system(size: 38, weight: .regular))
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(ink)
      Text(snapshot.brief)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(ink)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
      if !snapshot.preparations.isEmpty {
        HStack(spacing: 10) {
          ForEach(Array(snapshot.preparations.prefix(3)), id: \.self) { item in
            HStack(spacing: 5) {
              Image(systemName: preparationSymbol(item.type))
                .font(.system(size: 17, weight: .semibold))
              Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .foregroundStyle(ink)
        .frame(height: 34)
      }
      HStack(spacing: 7) {
        Text("다음 시간 예보")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(secondaryInk)
        Text(snapshot.nextTime)
          .font(.system(size: 12))
          .foregroundStyle(ink)
          .lineLimit(1)
        Spacer(minLength: 2)
        WeatherIconView(condition: snapshot.nextCondition, monochrome: true)
          .frame(width: 31, height: 31)
        Text(snapshot.nextTemperature)
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(ink)
      }
      MinMaxRow(snapshot: snapshot, size: 13)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .widgetInfoPanel()
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }
}

private func preparationSymbol(_ type: String) -> String {
  switch type {
  case "UMBRELLA": return "umbrella.fill"
  case "PARASOL": return "sun.max.fill"
  case "HEAVY_SNOW_CAUTION": return "snowflake"
  case "OUTERWEAR": return "tshirt.fill"
  case "MASK": return "facemask.fill"
  case "WATER": return "drop.fill"
  case "SUNSCREEN": return "sun.max.fill"
  default: return "checkmark.circle.fill"
  }
}

private struct WeatherIconView: View {
  let condition: String
  var monochrome = false

  var body: some View {
    Canvas { context, size in
      WeatherIconPainter.draw(
        condition: condition,
        monochrome: monochrome,
        context: &context,
        size: size
      )
    }
    .accessibilityLabel(weatherDescription(condition))
  }
}

private enum WeatherIconPainter {
  static let sun = Color(red: 246 / 255, green: 183 / 255, blue: 55 / 255)
  static let cloud = Color(red: 249 / 255, green: 252 / 255, blue: 1)
  static let cloudBlue = Color(red: 118 / 255, green: 151 / 255, blue: 180 / 255)
  static let cloudDark = Color(red: 84 / 255, green: 112 / 255, blue: 139 / 255)
  static let rain = Color(red: 73 / 255, green: 143 / 255, blue: 203 / 255)

  static func draw(
    condition: String,
    monochrome: Bool,
    context: inout GraphicsContext,
    size: CGSize
  ) {
    let s = min(size.width, size.height)
    let origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
    let cloudColor = monochrome ? ink : cloud
    let accent = monochrome ? ink : rain
    let snowColor = monochrome ? ink : Color.white

    switch condition {
    case "clear":
      drawSun(&context, center: point(origin, s, 0.5, 0.5), radius: s * 0.23,
              color: monochrome ? ink : sun)
    case "partlyCloudy":
      drawSun(&context, center: point(origin, s, 0.63, 0.33), radius: s * 0.17,
              color: monochrome ? ink : sun)
      drawCloud(&context, center: point(origin, s, 0.48, 0.49), width: s * 0.76,
                height: s * 0.39, color: cloudColor)
    case "overcast":
      drawCloud(&context, center: point(origin, s, 0.61, 0.39), width: s * 0.62,
                height: s * 0.33, color: monochrome ? ink : cloudBlue)
      drawCloud(&context, center: point(origin, s, 0.42, 0.57), width: s * 0.72,
                height: s * 0.38, color: monochrome ? ink : cloudDark)
    case "drizzle":
      drawCloud(&context, center: point(origin, s, 0.5, 0.39), width: s * 0.78,
                height: s * 0.4, color: cloudColor)
      drawDrop(&context, center: point(origin, s, 0.42, 0.69), radius: s * 0.026, color: accent)
      drawDrop(&context, center: point(origin, s, 0.58, 0.69), radius: s * 0.026, color: accent)
      drawDrop(&context, center: point(origin, s, 0.5, 0.84), radius: s * 0.026, color: accent)
    case "rain", "shower":
      let rainCloud = monochrome ? ink : condition == "shower" ? cloudDark : cloud
      drawCloud(&context, center: point(origin, s, 0.5, 0.36), width: s * 0.78,
                height: s * 0.4, color: rainCloud)
      for x in [CGFloat(0.32), CGFloat(0.5), CGFloat(0.68)] {
        drawDrop(&context, center: point(origin, s, x, 0.75), radius: s * 0.058, color: accent)
      }
    case "lightWintryMix":
      drawCloud(&context, center: point(origin, s, 0.5, 0.35), width: s * 0.8,
                height: s * 0.4, color: cloudColor)
      drawDrop(&context, center: point(origin, s, 0.24, 0.69), radius: s * 0.026, color: accent)
      drawDrop(&context, center: point(origin, s, 0.4, 0.69), radius: s * 0.026, color: accent)
      drawDrop(&context, center: point(origin, s, 0.32, 0.84), radius: s * 0.026, color: accent)
      drawSnow(&context, center: point(origin, s, 0.6, 0.69), radius: s * 0.026, color: snowColor)
      drawSnow(&context, center: point(origin, s, 0.76, 0.69), radius: s * 0.026, color: snowColor)
      drawSnow(&context, center: point(origin, s, 0.68, 0.84), radius: s * 0.026, color: snowColor)
    case "wintryMix":
      drawCloud(&context, center: point(origin, s, 0.5, 0.35), width: s * 0.8,
                height: s * 0.4, color: cloudColor)
      drawDrop(&context, center: point(origin, s, 0.36, 0.76), radius: s * 0.06, color: accent)
      drawSnow(&context, center: point(origin, s, 0.65, 0.77), radius: s * 0.12, color: snowColor)
    case "snowFlurry":
      drawCloud(&context, center: point(origin, s, 0.5, 0.35), width: s * 0.8,
                height: s * 0.4, color: cloudColor)
      drawSnow(&context, center: point(origin, s, 0.42, 0.69), radius: s * 0.026, color: snowColor)
      drawSnow(&context, center: point(origin, s, 0.58, 0.69), radius: s * 0.026, color: snowColor)
      drawSnow(&context, center: point(origin, s, 0.5, 0.84), radius: s * 0.026, color: snowColor)
    case "snow":
      drawCloud(&context, center: point(origin, s, 0.5, 0.35), width: s * 0.8,
                height: s * 0.4, color: cloudColor)
      drawSnow(&context, center: point(origin, s, 0.5, 0.77), radius: s * 0.13, color: snowColor)
    default:
      drawCloud(&context, center: point(origin, s, 0.5, 0.5), width: s * 0.8,
                height: s * 0.42, color: cloudColor)
      let question = context.resolve(
        Text("?").font(.system(size: s * 0.3, weight: .bold)).foregroundColor(monochrome ? ink : secondaryInk)
      )
      context.draw(question, at: point(origin, s, 0.52, 0.52), anchor: .center)
    }
  }

  private static func point(_ origin: CGPoint, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: origin.x + size * x, y: origin.y + size * y)
  }

  private static func drawSun(
    _ context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color
  ) {
    for index in 0..<8 {
      let angle = CGFloat(index) * .pi / 4
      var ray = Path()
      ray.move(to: CGPoint(x: center.x + cos(angle) * radius * 1.35,
                           y: center.y + sin(angle) * radius * 1.35))
      ray.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 1.72,
                              y: center.y + sin(angle) * radius * 1.72))
      context.stroke(ray, with: .color(color), style: StrokeStyle(lineWidth: radius * 0.12, lineCap: .round))
    }
    context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                        width: radius * 2, height: radius * 2)), with: .color(color))
  }

  private static func drawCloud(
    _ context: inout GraphicsContext,
    center: CGPoint,
    width: CGFloat,
    height: CGFloat,
    color: Color
  ) {
    let left = center.x - width / 2
    let top = center.y - height / 2
    var path = Path()
    path.addRoundedRect(
      in: CGRect(x: left, y: top + height * 0.42, width: width, height: height * 0.58),
      cornerSize: CGSize(width: height * 0.28, height: height * 0.28)
    )
    path.addEllipse(in: CGRect(x: left + width * 0.31 - height * 0.29,
                               y: top + height * 0.48 - height * 0.29,
                               width: height * 0.58, height: height * 0.58))
    path.addEllipse(in: CGRect(x: left + width * 0.53 - height * 0.38,
                               y: top + height * 0.32 - height * 0.38,
                               width: height * 0.76, height: height * 0.76))
    path.addEllipse(in: CGRect(x: left + width * 0.75 - height * 0.25,
                               y: top + height * 0.53 - height * 0.25,
                               width: height * 0.5, height: height * 0.5))
    context.fill(path, with: .color(color))
  }

  private static func drawDrop(
    _ context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color
  ) {
    var path = Path()
    path.move(to: CGPoint(x: center.x, y: center.y - radius * 1.55))
    path.addCurve(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.45),
                  control1: CGPoint(x: center.x - radius * 0.45, y: center.y - radius * 0.65),
                  control2: CGPoint(x: center.x - radius, y: center.y))
    path.addCurve(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.45),
                  control1: CGPoint(x: center.x - radius, y: center.y + radius * 1.1),
                  control2: CGPoint(x: center.x + radius, y: center.y + radius * 1.1))
    path.addCurve(to: CGPoint(x: center.x, y: center.y - radius * 1.55),
                  control1: CGPoint(x: center.x + radius, y: center.y),
                  control2: CGPoint(x: center.x + radius * 0.45, y: center.y - radius * 0.65))
    context.fill(path, with: .color(color))
  }

  private static func drawSnow(
    _ context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color
  ) {
    for index in 0..<3 {
      let angle = CGFloat(index) * .pi / 3
      let dx = cos(angle) * radius
      let dy = sin(angle) * radius
      var line = Path()
      line.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
      line.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
      context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: max(1.1, radius * 0.19), lineCap: .round))
    }
  }
}

private func weatherDescription(_ condition: String) -> String {
  switch condition {
  case "clear": return "맑음"
  case "partlyCloudy": return "구름 많음"
  case "overcast": return "흐림"
  case "drizzle": return "빗방울"
  case "rain": return "비"
  case "shower": return "소나기"
  case "lightWintryMix": return "빗방울과 눈날림"
  case "wintryMix": return "비와 눈"
  case "snowFlurry": return "눈날림"
  case "snow": return "눈"
  default: return "날씨 정보 없음"
  }
}

private extension View {
  func widgetInfoPanel() -> some View {
    background(Color.white.opacity(0.72))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  func weatherWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { surface }
    } else {
      background(surface)
    }
  }
}

@main
struct WeatherCareWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: widgetKind, provider: WeatherCareProvider()) { entry in
      WeatherCareWidgetView(entry: entry)
    }
    .configurationDisplayName("날씨챙겨")
    .description("현재 날씨와 외출 준비물을 한눈에 확인합니다.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
