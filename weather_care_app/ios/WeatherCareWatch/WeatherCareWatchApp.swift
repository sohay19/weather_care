import SwiftUI

enum WatchStyle {
  static let panel = Color(red: 37/255, green: 55/255, blue: 71/255)
  static let ink = Color(red: 237/255, green: 242/255, blue: 246/255)
  static let muted = Color(red: 170/255, green: 183/255, blue: 195/255)
  static let accent = Color(red: 157/255, green: 189/255, blue: 216/255)
  static func font(_ size: CGFloat, bold: Bool = false) -> Font {
    .custom(bold ? "SUITE-ExtraBold" : "SUITE-Regular", size: size, relativeTo: .body)
  }
}

@main
struct WeatherCareWatchApp: App {
  @StateObject private var store = WatchStore()
  var body: some Scene { WindowGroup { WatchHome().environmentObject(store).preferredColorScheme(.dark) } }
}

private struct WatchDetail: Hashable {
  let title: String
  let value: String
  let description: String
  let basis: String
}

private struct WatchHome: View {
  @EnvironmentObject private var store: WatchStore
  @Environment(\.scenePhase) private var phase
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var page = 0
  @State private var path: [WatchDetail] = []
  private let titles = ["날씨챙겨", "준비물", "타임라인", "기상·생활"]

  var body: some View {
    NavigationStack(path: $path) {
      TimelineView(.periodic(from: .now, by: 30)) { context in
        Group {
          if !store.snapshot.hasData {
            notice("iPhone에서 날씨챙겨를 열어 주세요", "선택한 지역의 날씨를 받으면 표시할게요.")
          } else {
            TabView(selection: $page) {
              current(at: context.date).tag(0)
              preparations(at: context.date).tag(1)
              hourly(at: context.date).tag(2)
              metrics(at: context.date).tag(3)
            }
            .tabViewStyle(.verticalPage)
          }
        }
      }
      .navigationTitle("")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Text(titles[page]).font(WatchStyle.font(12)).foregroundStyle(WatchStyle.accent)
        }
      }
      .navigationDestination(for: WatchDetail.self) { item in
        TimelineView(.periodic(from: .now, by: 30)) { context in detail(item, at: context.date) }
      }
      .onChange(of: store.snapshot.revision) { _, _ in path.removeAll() }
      .onChange(of: phase) { _, value in if value == .active { store.refresh() } }
      .onOpenURL { _ in path.removeAll(); page = 0 }
    }
    .tint(WatchStyle.accent)
    .font(WatchStyle.font(14))
    .foregroundStyle(WatchStyle.ink)
  }

  private func current(at now: Date) -> some View {
    ScrollView {
      VStack(spacing: 5) {
        Text(store.snapshot.region).font(WatchStyle.font(13)).foregroundStyle(WatchStyle.accent)
        HStack(spacing: 7) {
          WatchWeatherIcon(condition: store.snapshot.condition).frame(width: 36, height: 36)
          Text(store.snapshot.temperature).font(WatchStyle.font(40, bold: true)).lineLimit(1).minimumScaleFactor(0.65)
        }
        Text("체감 \(store.snapshot.apparent) · 최저 \(store.snapshot.minimum) / 최고 \(store.snapshot.maximum)")
          .font(WatchStyle.font(11)).foregroundStyle(WatchStyle.muted)
        if store.snapshot.stale(at: now) {
          Text("마지막 기록 · 오래된 자료").font(WatchStyle.font(12)).foregroundStyle(WatchStyle.accent)
        } else {
          VStack(spacing: 3) {
            Text(store.snapshot.comparison).foregroundStyle(WatchStyle.accent)
            Text(store.snapshot.apparentComparison).font(WatchStyle.font(10)).foregroundStyle(WatchStyle.muted)
          }.font(WatchStyle.font(12)).frame(maxWidth: .infinity).padding(6)
            .background(WatchStyle.panel, in: RoundedRectangle(cornerRadius: 16))
        }
        Text(store.snapshot.time + " 기준").font(WatchStyle.font(10)).foregroundStyle(WatchStyle.muted)
        refreshButton
      }.multilineTextAlignment(.center).padding(.horizontal, 4)
    }
  }

  private func preparations(at now: Date) -> some View {
    ScrollView {
      VStack(spacing: 7) {
        Text("오늘의 준비물").font(WatchStyle.font(13)).foregroundStyle(WatchStyle.accent).frame(maxWidth: .infinity)
        if store.snapshot.stale(at: now) {
          Text("오래된 자료예요\n최신 날씨를 확인해 주세요").multilineTextAlignment(.center)
        } else if store.snapshot.preparations(at: now).isEmpty {
          Text("지금 챙길 물건이 없어요").font(WatchStyle.font(13))
        } else {
          ForEach(store.snapshot.preparations(at: now)) { item in
            HStack(spacing: 0) {
              NavigationLink(value: WatchDetail(title: item.label, value: "", description: item.reason, basis: store.snapshot.time + " 기준")) {
                HStack(spacing: 6) {
                  Image("prep_" + item.id.lowercased()).renderingMode(.template).resizable().scaledToFit()
                    .foregroundStyle(WatchStyle.accent).frame(width: 23, height: 23)
                  Text(item.label).font(WatchStyle.font(14))
                }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 48).padding(.leading, 9)
                  .contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityIdentifier("prep-detail-" + item.id)
              Button { store.toggle(item) } label: {
                Image(systemName: store.checked(item) ? "checkmark.square.fill" : "square")
                  .font(.system(size: 23)).frame(width: 44, height: 48).contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityLabel(item.label + " 챙김")
                .accessibilityValue(store.checked(item) ? "완료" : "미완료")
                .accessibilityIdentifier("prep-check-" + item.id)
            }.background(WatchStyle.panel, in: RoundedRectangle(cornerRadius: 17))
          }
        }
        refreshButton
      }
    }
  }

  private func hourly(at now: Date) -> some View {
    ScrollView {
      VStack(spacing: 6) {
        Text("시간별 예보 · 강수확률").font(WatchStyle.font(11)).foregroundStyle(WatchStyle.muted)
          .frame(maxWidth: .infinity).multilineTextAlignment(.center)
        if store.snapshot.hours(at: now).isEmpty {
          Text(store.snapshot.stale(at: now) ? "오래된 자료예요" : "시간별 자료 없음").font(WatchStyle.font(13))
        }
        ForEach(store.snapshot.hours(at: now)) { hour in
          HStack(spacing: 5) {
            Text(hour.label).frame(minWidth: 28, alignment: .leading)
            WatchWeatherIcon(condition: hour.condition).frame(width: 23, height: 23)
            Text(hour.temperature).font(WatchStyle.font(18)).frame(maxWidth: .infinity)
            Text(hour.rain).foregroundStyle(WatchStyle.accent).frame(minWidth: 32, alignment: .trailing)
          }.font(WatchStyle.font(12)).padding(8).background(WatchStyle.panel, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
        refreshButton
      }
    }
  }

  private func metrics(at now: Date) -> some View {
    ScrollView {
      VStack(spacing: 7) {
        Text("항목을 눌러 내용 확인").font(WatchStyle.font(11)).foregroundStyle(WatchStyle.muted).frame(maxWidth: .infinity)
        if store.snapshot.stale(at: now) {
          Text("오래된 자료예요\n최신 날씨를 확인해 주세요").multilineTextAlignment(.center)
        } else {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 7) {
            ForEach(store.snapshot.metrics) { item in
              NavigationLink(value: WatchDetail(title: item.name, value: item.value, description: item.description, basis: item.basis)) {
                VStack(spacing: 4) {
                  Text(item.name).font(WatchStyle.font(11)).foregroundStyle(WatchStyle.muted)
                  Text(item.value).font(WatchStyle.font(18, bold: true)).multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.75)
                }.frame(maxWidth: .infinity, minHeight: 63).padding(4)
                  .background(WatchStyle.panel, in: RoundedRectangle(cornerRadius: 17))
              }.buttonStyle(.plain).accessibilityIdentifier("metric-" + item.name)
            }
          }
        }
        refreshButton
      }
    }
  }

  private func detail(_ item: WatchDetail, at now: Date) -> some View {
    ScrollView {
      VStack(spacing: 12) {
        if store.snapshot.stale(at: now) {
          Text("오래된 자료예요\n최신 날씨를 확인해 주세요")
        } else {
          Text(item.title).font(WatchStyle.font(20)).foregroundStyle(WatchStyle.accent)
          if !item.value.isEmpty { Text(item.value).font(WatchStyle.font(32, bold: true)) }
          Text(item.description).font(WatchStyle.font(13))
          VStack(spacing: 5) {
            Text(store.snapshot.region)
            Text(item.basis)
          }.font(WatchStyle.font(11)).foregroundStyle(WatchStyle.muted).padding(.top, 8)
        }
        Button("목록으로") { path.removeAll() }.buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: 46)
          .background(WatchStyle.panel, in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("detail-back")
      }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }.navigationTitle("상세")
  }

  private func notice(_ title: String, _ message: String) -> some View {
    ScrollView {
      VStack(spacing: 12) {
        Image(systemName: "iphone.and.arrow.forward").font(.title2).foregroundStyle(WatchStyle.accent)
        Text(title).font(WatchStyle.font(17))
        Text(message).font(WatchStyle.font(12)).foregroundStyle(WatchStyle.muted)
        refreshButton
      }.multilineTextAlignment(.center)
    }
  }

  private var refreshButton: some View {
    VStack(spacing: 4) {
      if !store.status.isEmpty { Text(store.status).font(WatchStyle.font(10)).foregroundStyle(WatchStyle.muted) }
      Button("새로고침") { store.refresh() }.font(WatchStyle.font(12)).accessibilityIdentifier("watch-refresh")
    }
  }
}
