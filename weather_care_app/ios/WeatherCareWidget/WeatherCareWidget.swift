import Foundation
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private let widgetKind = "WeatherCareWidget"
private let appGroup = "group.com.codesoha.weathercare"
private let snapshotKey = "snapshot"
private let weatherCareHomeURL = URL(string: "weathercare://home")!
private let ink = Color(red: 37 / 255, green: 55 / 255, blue: 78 / 255)
private let secondaryInk = Color(red: 96 / 255, green: 117 / 255, blue: 138 / 255)
private let surface = Color(red: 234 / 255, green: 244 / 255, blue: 251 / 255)
private let preparationCircle = Color(red: 226 / 255, green: 239 / 255, blue: 248 / 255)
private let refreshButtonSurface = Color(red: 71 / 255, green: 111 / 255, blue: 152 / 255)
private let refreshButtonHitSurface = RadialGradient(
  stops: [
    .init(color: refreshButtonSurface, location: 0),
    .init(color: refreshButtonSurface, location: 0.499),
    .init(color: surface, location: 0.5),
    .init(color: surface, location: 1),
  ],
  center: .center,
  startRadius: 0,
  endRadius: 22
)
private let widgetHorizontalMarginRatio: CGFloat = 0.75
private let widgetTopMarginRatio: CGFloat = 0.25
private let widgetBottomMarginRatio: CGFloat = 0.65

private enum SuiteFont {
  static func regular(_ size: CGFloat) -> Font { .custom("SUITE-Regular", fixedSize: size) }
  static func semiBold(_ size: CGFloat) -> Font { .custom("SUITE-SemiBold", fixedSize: size) }
  static func bold(_ size: CGFloat) -> Font { .custom("SUITE-Bold", fixedSize: size) }
  static func extraBold(_ size: CGFloat) -> Font { .custom("SUITE-ExtraBold", fixedSize: size) }
  static func heavy(_ size: CGFloat) -> Font { .custom("SUITE-Heavy", fixedSize: size) }
}

struct WeatherCareEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct WeatherCareProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeatherCareEntry {
    WeatherCareEntry(date: Date(), snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (WeatherCareEntry) -> Void) {
    let now = Date()
    completion(WeatherCareEntry(date: now, snapshot: WidgetSnapshot.load().at(now)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherCareEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetSnapshot.load()
    let dates = snapshot.timelineDates(after: now)
    let entries = dates.map { date in
      WeatherCareEntry(date: date, snapshot: snapshot.at(date))
    }
    let refresh = snapshot.nextRefresh(after: dates.last ?? now)
    completion(Timeline(
      entries: entries,
      policy: refresh.map(TimelineReloadPolicy.after) ?? .atEnd
    ))
  }
}

struct WidgetPreparation: Codable, Hashable {
  let type: String
  let label: String
}

struct WidgetBriefingEntry: Codable {
  let briefingId: String
  let sceneId: String
  let validFrom: String
  let validUntil: String
  let shortMessage: String
  let mediumMessage: String
  let longMessage: String
  let recommendedItems: [String]

  func active(at date: Date) -> Bool {
    guard let from = widgetDate(validFrom), let until = widgetDate(validUntil) else {
      return false
    }
    return from <= date && date < until
  }
}

struct WidgetSnapshot: Codable {
  let briefingId: String?
  let sceneId: String?
  let validFrom: String?
  let validUntil: String?
  let nextBriefingBoundary: String?
  let dataFreshUntil: String?
  let briefingTimeline: [WidgetBriefingEntry]?
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
  let preparationCatalog: [WidgetPreparation]?

  static let placeholder = WidgetSnapshot(
    briefingId: nil,
    sceneId: nil,
    validFrom: nil,
    validUntil: nil,
    nextBriefingBoundary: nil,
    dataFreshUntil: nil,
    briefingTimeline: nil,
    region: "시흥시 은행동",
    refreshTime: "오전 8:20 기준",
    condition: "partlyCloudy",
    currentTemperature: "18°",
    apparentTemperature: "18°",
    minimumTemperature: "12°",
    maximumTemperature: "20°",
    shortMessage: "두꺼운 겉옷을 챙기세요",
    brief: "오전에는 선선하고 오후에는 포근해요. 얇은 겉옷을 챙기면 좋아요.",
    nextTime: "오전 9시",
    nextCondition: "clear",
    nextTemperature: "19°",
    preparations: [
      WidgetPreparation(type: "UMBRELLA", label: "우산"),
      WidgetPreparation(type: "OUTERWEAR", label: "두꺼운 겉옷"),
      WidgetPreparation(type: "MASK", label: "마스크")
    ],
    preparationCatalog: nil
  )

  static let empty = WidgetSnapshot(
    briefingId: nil,
    sceneId: nil,
    validFrom: nil,
    validUntil: nil,
    nextBriefingBoundary: nil,
    dataFreshUntil: nil,
    briefingTimeline: nil,
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
    preparations: [],
    preparationCatalog: nil
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

  func at(_ date: Date) -> WidgetSnapshot {
    let freshUntil = dataFreshUntil.flatMap(widgetDate)
    let active = briefingTimeline?.first { $0.active(at: date) }
    let legacyValid = validUntil.flatMap(widgetDate).map { date < $0 } ?? true
    guard freshUntil.map({ date < $0 }) ?? true,
          active != nil || (briefingTimeline?.isEmpty ?? true) && legacyValid else {
      return replacingBriefing(
        id: nil,
        scene: "UNAVAILABLE",
        short: "최신 날씨를 확인해 주세요.",
        long: "최신 날씨를 확인해 주세요.",
        preparations: []
      )
    }
    guard let active else { return self }
    let intended = Set(active.recommendedItems)
    return replacingBriefing(
      id: active.briefingId,
      scene: active.sceneId,
      short: active.shortMessage,
      long: active.longMessage,
      preparations: (preparationCatalog ?? preparations)
        .filter { intended.contains($0.type) }
        .prefix(3)
        .map { $0 }
    )
  }

  func timelineDates(after now: Date) -> [Date] {
    var dates = [now]
    for entry in briefingTimeline ?? [] {
      if let from = widgetDate(entry.validFrom), from > now { dates.append(from) }
      if let until = widgetDate(entry.validUntil), until > now { dates.append(until) }
    }
    return Array(Set(dates)).sorted()
  }

  func nextRefresh(after date: Date) -> Date? {
    let boundaries = [nextBriefingBoundary, dataFreshUntil]
      .compactMap { $0.flatMap(widgetDate) }
      .filter { $0 > date }
    return boundaries.min()
  }

  private func replacingBriefing(
    id: String?,
    scene: String?,
    short: String,
    long: String,
    preparations: [WidgetPreparation]
  ) -> WidgetSnapshot {
    WidgetSnapshot(
      briefingId: id,
      sceneId: scene,
      validFrom: validFrom,
      validUntil: validUntil,
      nextBriefingBoundary: nextBriefingBoundary,
      dataFreshUntil: dataFreshUntil,
      briefingTimeline: briefingTimeline,
      region: region,
      refreshTime: refreshTime,
      condition: condition,
      currentTemperature: currentTemperature,
      apparentTemperature: apparentTemperature,
      minimumTemperature: minimumTemperature,
      maximumTemperature: maximumTemperature,
      shortMessage: short,
      brief: long,
      nextTime: nextTime,
      nextCondition: nextCondition,
      nextTemperature: nextTemperature,
      preparations: preparations,
      preparationCatalog: preparationCatalog
    )
  }
}

private func widgetDate(_ value: String) -> Date? {
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}

struct WeatherCareWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: WeatherCareEntry

  var body: some View {
    interactiveContent
      .reducedWidgetContentMargins()
      .weatherWidgetBackground()
  }

  @ViewBuilder
  private var interactiveContent: some View {
    widgetContent.widgetURL(weatherCareHomeURL)
  }

  @ViewBuilder
  private var widgetContent: some View {
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
  }
}

private struct WidgetHeader: View {
  let snapshot: WidgetSnapshot
  let regionSize: CGFloat
  let timeSize: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      Text(snapshot.region)
        .font(SuiteFont.extraBold(regionSize))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Spacer(minLength: 2)
      Text(snapshot.refreshTime)
        .font(SuiteFont.regular(timeSize))
        .foregroundStyle(secondaryInk)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
      WidgetRefreshButton()
    }
    .foregroundStyle(ink)
  }
}

private struct SmallWidgetHeader: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      VStack(alignment: .leading, spacing: 1) {
        Text(snapshot.region)
          .font(SuiteFont.extraBold(12))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(snapshot.refreshTime)
          .font(SuiteFont.regular(9))
          .foregroundStyle(secondaryInk)
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
      }
      .padding(.top, 13)
      Spacer(minLength: 2)
      WidgetRefreshButton()
    }
    .foregroundStyle(ink)
  }
}

private struct WidgetRefreshButton: View {
  @ViewBuilder
  var body: some View {
    if #available(iOS 17.0, *) {
      Button(intent: RefreshWeatherWidgetIntent()) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 8.8, weight: .semibold))
          .foregroundStyle(Color.white)
          .frame(width: 44, height: 44)
          .background(refreshButtonHitSurface, in: Circle())
          .contentShape(.interaction, Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("날씨 새로고침")
      .padding(.trailing, -11)
    }
  }
}

private struct MinMaxRow: View {
  let snapshot: WidgetSnapshot
  let size: CGFloat

  var body: some View {
    (Text("최저 ").font(SuiteFont.regular(size))
      + Text(snapshot.minimumTemperature).font(SuiteFont.extraBold(size))
      + Text("  최고 ").font(SuiteFont.regular(size))
      + Text(snapshot.maximumTemperature).font(SuiteFont.extraBold(size)))
      .foregroundStyle(ink.opacity(0.82))
      .lineLimit(1)
      .minimumScaleFactor(0.62)
  }
}

private struct AdaptiveTemperatureRow: View {
  let condition: String
  let currentTemperature: String
  let apparentTemperature: String?
  let iconSize: CGFloat
  let temperatureSize: CGFloat
  let labelSize: CGFloat
  let spacing: CGFloat
  let dividerHeight: CGFloat

  var body: some View {
    GeometryReader { geometry in
      let scale = fittedScale(availableWidth: geometry.size.width)

      HStack(spacing: spacing * scale) {
        WeatherIconView(condition: condition)
          .frame(width: iconSize * scale, height: iconSize * scale)

        if let apparentTemperature {
          temperatureColumn(label: "현재", value: currentTemperature, scale: scale)
          Divider()
            .frame(width: 1, height: dividerHeight * scale)
            .overlay(Color(red: 171 / 255, green: 195 / 255, blue: 214 / 255))
          temperatureColumn(label: "체감", value: apparentTemperature, scale: scale)
        } else {
          temperatureText(currentTemperature, scale: scale)
        }
      }
      .foregroundStyle(ink)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .frame(height: iconSize)
  }

  private func fittedScale(availableWidth: CGFloat) -> CGFloat {
    guard availableWidth > 2 else { return 0.1 }
    return min(1, max(0.1, (availableWidth - 2) / idealWidth))
  }

  private var idealWidth: CGFloat {
    let currentWidth = temperatureColumnWidth(label: "현재", value: currentTemperature)
    guard let apparentTemperature else {
      return iconSize + spacing + currentWidth
    }
    let apparentWidth = temperatureColumnWidth(label: "체감", value: apparentTemperature)
    return iconSize + currentWidth + apparentWidth + (spacing * 3) + 1
  }

  private func temperatureColumnWidth(label: String, value: String) -> CGFloat {
    let valueWidth = measuredSuiteTextWidth(value, fontName: "SUITE-Heavy", size: temperatureSize)
    guard apparentTemperature != nil else { return valueWidth }
    let labelWidth = measuredSuiteTextWidth(label, fontName: "SUITE-Regular", size: labelSize)
    return max(valueWidth, labelWidth)
  }

  private func temperatureColumn(label: String, value: String, scale: CGFloat) -> some View {
    VStack(spacing: -1 * scale) {
      Text(label)
        .font(SuiteFont.regular(labelSize * scale))
        .foregroundStyle(secondaryInk)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
      temperatureText(value, scale: scale)
    }
  }

  private func temperatureText(_ value: String, scale: CGFloat) -> some View {
    Text(value)
      .font(SuiteFont.heavy(temperatureSize * scale))
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
  }
}

private func measuredSuiteTextWidth(_ value: String, fontName: String, size: CGFloat) -> CGFloat {
  let font = UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: .heavy)
  return ceil((value as NSString).size(withAttributes: [.font: font]).width)
}

private struct SmallWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 4) {
      SmallWidgetHeader(snapshot: snapshot)
      AdaptiveTemperatureRow(
        condition: snapshot.condition,
        currentTemperature: snapshot.currentTemperature,
        apparentTemperature: nil,
        iconSize: 64,
        temperatureSize: 38,
        labelSize: 0,
        spacing: 8,
        dividerHeight: 0
      )
      .frame(maxWidth: .infinity, alignment: .center)
      .frame(maxHeight: .infinity)
      MinMaxRow(snapshot: snapshot, size: 13)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .widgetInfoPanel()
    }
    .padding(.horizontal, 2 * widgetHorizontalMarginRatio)
  }
}

private struct MediumWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 3) {
      WidgetHeader(snapshot: snapshot, regionSize: 13, timeSize: 10)
      AdaptiveTemperatureRow(
        condition: snapshot.condition,
        currentTemperature: snapshot.currentTemperature,
        apparentTemperature: snapshot.apparentTemperature,
        iconSize: 58,
        temperatureSize: 34,
        labelSize: 10,
        spacing: 12,
        dividerHeight: 36
      )
      .frame(maxWidth: .infinity, alignment: .center)
      .frame(maxHeight: .infinity)
      HStack(spacing: 8) {
        Text(snapshot.shortMessage)
          .font(SuiteFont.extraBold(13))
          .lineLimit(1)
        Spacer(minLength: 2)
        MinMaxRow(snapshot: snapshot, size: 12)
      }
      .foregroundStyle(ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .widgetInfoPanel()
    }
    .padding(.horizontal, 2 * widgetHorizontalMarginRatio)
  }
}

private struct LargeWeatherWidget: View {
  let snapshot: WidgetSnapshot

  var body: some View {
    VStack(spacing: 5) {
      WidgetHeader(snapshot: snapshot, regionSize: 14, timeSize: 11)
      VStack(spacing: 20) {
        AdaptiveTemperatureRow(
          condition: snapshot.condition,
          currentTemperature: snapshot.currentTemperature,
          apparentTemperature: snapshot.apparentTemperature,
          iconSize: 72,
          temperatureSize: 38,
          labelSize: 11,
          spacing: 12,
          dividerHeight: 40
        )
        .frame(maxWidth: .infinity, alignment: .center)
        Text(snapshot.brief)
          .font(SuiteFont.extraBold(14))
          .foregroundStyle(ink)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18)
        if !snapshot.preparations.isEmpty {
          HStack(spacing: 6) {
            ForEach(Array(snapshot.preparations.prefix(3)), id: \.self) { item in
              HStack(spacing: 4) {
                PreparationIconView(type: item.type)
                  .frame(width: 36, height: 36)
                Text(item.label)
                  .font(SuiteFont.extraBold(12))
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
              }
              .frame(maxWidth: .infinity)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .widgetInfoPanel()
            }
          }
          .foregroundStyle(ink)
        }
      }
      .frame(maxHeight: .infinity, alignment: .center)
      HStack(spacing: 0) {
        Text("다음 시간 예보")
          .font(SuiteFont.extraBold(12))
          .foregroundStyle(ink)
          .lineLimit(1)
          .padding(.trailing, 10)
        Text(snapshot.nextTime)
          .font(SuiteFont.regular(12))
          .foregroundStyle(ink)
          .lineLimit(1)
          .frame(maxWidth: .infinity)
        Text(snapshot.nextTemperature)
          .font(SuiteFont.heavy(17))
          .foregroundStyle(ink)
        WeatherIconView(condition: snapshot.nextCondition, monochrome: true)
          .frame(width: 32, height: 32)
          .padding(.leading, 3)
          .padding(.trailing, 10)
      }
      .padding(.leading, 12)
      .padding(.trailing, 18)
      MinMaxRow(snapshot: snapshot, size: 13)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .widgetInfoPanel()
    }
    .padding(.horizontal, 3 * widgetHorizontalMarginRatio)
  }
}

private struct PreparationIconView: View {
  let type: String

  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        Circle().fill(preparationCircle)
        if let image = preparationImage(type) {
          Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(side * 0.16)
        } else {
          Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            PreparationIconPainter.draw(
              type: type,
              context: &context,
              rect: rect.insetBy(dx: side * 0.18, dy: side * 0.18)
            )
          }
        }
      }
      .frame(width: side, height: side)
      .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    .accessibilityLabel(preparationDescription(type))
  }
}

private func preparationImage(_ type: String) -> UIImage? {
  guard
    let name = preparationAssetName(type),
    let url = Bundle.main.url(
      forResource: name,
      withExtension: "png",
      subdirectory: "Icons"
    )
  else { return nil }
  return UIImage(contentsOfFile: url.path)
}

private func preparationAssetName(_ type: String) -> String? {
  switch type {
  case "UMBRELLA": return "prep_umbrella"
  case "RAINCOAT": return "prep_raincoat"
  case "RAIN_BOOTS": return "prep_rain_boots"
  case "PARASOL": return "prep_parasol"
  case "SUNSCREEN": return "prep_sunscreen"
  case "SUNGLASSES": return "prep_sunglasses"
  case "WATER": return "prep_water"
  case "PORTABLE_FAN": return "prep_portable_fan"
  case "COOLING_ITEM": return "prep_cooling_item"
  case "OUTERWEAR": return "prep_outerwear"
  case "SCARF": return "prep_scarf"
  case "HAND_WARMER": return "prep_hand_warmer"
  case "SNOW_CHAINS": return "prep_snow_chains"
  case "POWER_BANK": return "prep_power_bank"
  case "WINTER_BOOTS": return "prep_winter_boots"
  default: return nil
  }
}

private enum PreparationIconPainter {
  static func draw(
    type: String,
    context: inout GraphicsContext,
    rect: CGRect
  ) {
    let style = StrokeStyle(
      lineWidth: rect.width * 0.075,
      lineCap: .round,
      lineJoin: .round
    )
    switch type {
    case "PARASOL":
      drawUmbrella(context: &context, rect: rect, style: style, parasol: true)
    case "HEAVY_SNOW_CAUTION":
      drawSnowflake(context: &context, rect: rect, style: style)
    case "OUTERWEAR":
      drawOuterwear(context: &context, rect: rect, style: style)
    case "MASK":
      drawMask(context: &context, rect: rect, style: style)
    case "WATER":
      drawBottle(context: &context, rect: rect, style: style, sunscreen: false)
    case "SUNSCREEN":
      drawBottle(context: &context, rect: rect, style: style, sunscreen: true)
    default:
      drawUmbrella(context: &context, rect: rect, style: style, parasol: false)
    }
  }

  private static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(
      x: rect.minX + rect.width * x / 100,
      y: rect.minY + rect.height * y / 100
    )
  }

  private static func drawUmbrella(
    context: inout GraphicsContext,
    rect: CGRect,
    style: StrokeStyle,
    parasol: Bool
  ) {
    var canopy = Path()
    canopy.move(to: point(13, 51, in: rect))
    canopy.addQuadCurve(
      to: point(87, 51, in: rect),
      control: point(50, 8, in: rect)
    )
    context.stroke(canopy, with: .color(ink), style: style)

    var handle = Path()
    handle.move(to: point(50, 31, in: rect))
    handle.addLine(to: point(50, 77, in: rect))
    handle.addCurve(
      to: point(68, 77, in: rect),
      control1: point(50, 88, in: rect),
      control2: point(68, 88, in: rect)
    )
    context.stroke(handle, with: .color(ink), style: style)

    guard parasol else { return }
    let sunCenter = point(78, 18, in: rect)
    let sunRadius = rect.width * 0.065
    context.stroke(
      Path(ellipseIn: CGRect(
        x: sunCenter.x - sunRadius,
        y: sunCenter.y - sunRadius,
        width: sunRadius * 2,
        height: sunRadius * 2
      )),
      with: .color(ink),
      style: style
    )
    for index in 0..<4 {
      let angle = CGFloat(index) * .pi / 2
      var ray = Path()
      ray.move(to: CGPoint(
        x: sunCenter.x + cos(angle) * sunRadius * 1.45,
        y: sunCenter.y + sin(angle) * sunRadius * 1.45
      ))
      ray.addLine(to: CGPoint(
        x: sunCenter.x + cos(angle) * sunRadius * 1.95,
        y: sunCenter.y + sin(angle) * sunRadius * 1.95
      ))
      context.stroke(ray, with: .color(ink), style: style)
    }
  }

  private static func drawSnowflake(
    context: inout GraphicsContext,
    rect: CGRect,
    style: StrokeStyle
  ) {
    let center = point(50, 50, in: rect)
    let radius = rect.width * 0.35
    for index in 0..<3 {
      let angle = CGFloat(index) * .pi / 3
      let offset = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
      var branch = Path()
      branch.move(to: CGPoint(x: center.x - offset.x, y: center.y - offset.y))
      branch.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
      context.stroke(branch, with: .color(ink), style: style)
    }
  }

  private static func drawOuterwear(
    context: inout GraphicsContext,
    rect: CGRect,
    style: StrokeStyle
  ) {
    var coat = Path()
    coat.move(to: point(38, 20, in: rect))
    coat.addLine(to: point(20, 36, in: rect))
    coat.addLine(to: point(27, 55, in: rect))
    coat.addLine(to: point(36, 50, in: rect))
    coat.addLine(to: point(33, 86, in: rect))
    coat.addLine(to: point(67, 86, in: rect))
    coat.addLine(to: point(64, 50, in: rect))
    coat.addLine(to: point(73, 55, in: rect))
    coat.addLine(to: point(80, 36, in: rect))
    coat.addLine(to: point(62, 20, in: rect))
    coat.addLine(to: point(50, 34, in: rect))
    coat.closeSubpath()
    coat.move(to: point(50, 34, in: rect))
    coat.addLine(to: point(50, 85, in: rect))
    context.stroke(coat, with: .color(ink), style: style)
  }

  private static func drawMask(
    context: inout GraphicsContext,
    rect: CGRect,
    style: StrokeStyle
  ) {
    let maskRect = CGRect(
      x: point(20, 30, in: rect).x,
      y: point(20, 30, in: rect).y,
      width: rect.width * 0.6,
      height: rect.height * 0.42
    )
    context.stroke(
      Path(roundedRect: maskRect, cornerRadius: rect.width * 0.11),
      with: .color(ink),
      style: style
    )
    var loops = Path()
    loops.move(to: point(20, 38, in: rect))
    loops.addCurve(
      to: point(20, 66, in: rect),
      control1: point(2, 35, in: rect),
      control2: point(2, 69, in: rect)
    )
    loops.move(to: point(80, 38, in: rect))
    loops.addCurve(
      to: point(80, 66, in: rect),
      control1: point(98, 35, in: rect),
      control2: point(98, 69, in: rect)
    )
    loops.move(to: point(30, 46, in: rect))
    loops.addLine(to: point(70, 46, in: rect))
    loops.move(to: point(30, 58, in: rect))
    loops.addLine(to: point(70, 58, in: rect))
    context.stroke(loops, with: .color(ink), style: style)
  }

  private static func drawBottle(
    context: inout GraphicsContext,
    rect: CGRect,
    style: StrokeStyle,
    sunscreen: Bool
  ) {
    let bodyRect = CGRect(
      x: point(31, 31, in: rect).x,
      y: point(31, 31, in: rect).y,
      width: rect.width * 0.38,
      height: rect.height * 0.57
    )
    context.stroke(
      Path(roundedRect: bodyRect, cornerRadius: rect.width * 0.08),
      with: .color(ink),
      style: style
    )
    var cap = Path()
    cap.addRect(CGRect(
      x: point(40, 17, in: rect).x,
      y: point(40, 17, in: rect).y,
      width: rect.width * 0.2,
      height: rect.height * 0.14
    ))
    context.stroke(cap, with: .color(ink), style: style)

    if sunscreen {
      let center = point(50, 58, in: rect)
      let radius = rect.width * 0.09
      context.stroke(
        Path(ellipseIn: CGRect(
          x: center.x - radius,
          y: center.y - radius,
          width: radius * 2,
          height: radius * 2
        )),
        with: .color(ink),
        style: style
      )
      for index in 0..<4 {
        let angle = CGFloat(index) * .pi / 2
        var ray = Path()
        ray.move(to: CGPoint(
          x: center.x + cos(angle) * radius * 1.3,
          y: center.y + sin(angle) * radius * 1.3
        ))
        ray.addLine(to: CGPoint(
          x: center.x + cos(angle) * radius * 1.65,
          y: center.y + sin(angle) * radius * 1.65
        ))
        context.stroke(ray, with: .color(ink), style: style)
      }
    } else {
      var drop = Path()
      drop.move(to: point(50, 46, in: rect))
      drop.addQuadCurve(to: point(50, 70, in: rect), control: point(38, 63, in: rect))
      drop.addQuadCurve(to: point(50, 46, in: rect), control: point(62, 63, in: rect))
      context.stroke(drop, with: .color(ink), style: style)
    }
  }
}

private func preparationDescription(_ type: String) -> String {
  switch type {
  case "UMBRELLA": return "우산"
  case "RAINCOAT": return "우비"
  case "RAIN_BOOTS": return "장화"
  case "PARASOL": return "양산"
  case "SUNSCREEN": return "선크림"
  case "SUNGLASSES": return "선글라스"
  case "WATER": return "물"
  case "PORTABLE_FAN": return "휴대용 선풍기"
  case "COOLING_ITEM": return "쿨링제품"
  case "OUTERWEAR": return "두꺼운 겉옷"
  case "SCARF": return "목도리"
  case "HAND_WARMER": return "핫팩"
  case "SNOW_CHAINS": return "스노우체인"
  case "POWER_BANK": return "보조배터리"
  case "WINTER_BOOTS": return "방한부츠"
  case "HEAVY_SNOW_CAUTION": return "많은 눈 대비"
  case "MASK": return "마스크"
  default: return "준비물"
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
        Text("?").font(SuiteFont.bold(s * 0.3)).foregroundColor(monochrome ? ink : secondaryInk)
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
  @ViewBuilder
  func reducedWidgetContentMargins() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      modifier(ReducedWidgetContentMargins())
    } else {
      modifier(LegacyReducedWidgetContentMargins())
    }
  }

  func widgetInfoPanel() -> some View {
    background(Color.white.opacity(0.72))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

@available(iOSApplicationExtension 17.0, *)
private struct ReducedWidgetContentMargins: ViewModifier {
  @Environment(\.widgetContentMargins) private var margins

  func body(content: Content) -> some View {
    content.padding(
      EdgeInsets(
        top: margins.top * widgetTopMarginRatio,
        leading: margins.leading * widgetHorizontalMarginRatio,
        bottom: margins.bottom * widgetBottomMarginRatio,
        trailing: margins.trailing * widgetHorizontalMarginRatio
      )
    )
  }
}

private struct LegacyReducedWidgetContentMargins: ViewModifier {
  func body(content: Content) -> some View {
    GeometryReader { geometry in
      content
        .padding(
          EdgeInsets(
            top: geometry.safeAreaInsets.top * widgetTopMarginRatio,
            leading: geometry.safeAreaInsets.leading * widgetHorizontalMarginRatio,
            bottom: geometry.safeAreaInsets.bottom * widgetBottomMarginRatio,
            trailing: geometry.safeAreaInsets.trailing * widgetHorizontalMarginRatio
          )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .ignoresSafeArea()
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
    .contentMarginsDisabled()
  }
}
