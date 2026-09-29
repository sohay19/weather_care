import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let homeWidgetChannel = "com.codesoha.weathercare/home-widget"
  private let homeWidgetGroup = "group.com.codesoha.weathercare"
  private let homeWidgetSnapshotKey = "snapshot"
  private let homeWidgetRefreshURLKey = "refresh_url"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let widgetGroup = homeWidgetGroup
      let widgetSnapshotKey = homeWidgetSnapshotKey
      let widgetRefreshURLKey = homeWidgetRefreshURLKey
      let channel = FlutterMethodChannel(
        name: homeWidgetChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard let defaults = UserDefaults(suiteName: widgetGroup) else {
          result(FlutterError(
            code: "WIDGET_STORAGE_UNAVAILABLE",
            message: "위젯 공유 저장소를 열지 못했습니다.",
            details: nil
          ))
          return
        }
        switch call.method {
        case "save":
          let values = call.arguments as? [String: Any]
          let snapshot = values?["snapshot"] as? String ?? call.arguments as? String
          guard let snapshot else {
            result(FlutterError(
              code: "INVALID_WIDGET_DATA",
              message: "위젯 자료가 비어 있습니다.",
              details: nil
            ))
            return
          }
          let storedSnapshot = weatherWidgetSnapshotPreservingSpecificRegion(
            snapshot,
            previous: defaults.string(forKey: widgetSnapshotKey)
          )
          defaults.set(storedSnapshot, forKey: widgetSnapshotKey)
          if let refreshURL = values?["refreshUrl"] as? String,
             !refreshURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(refreshURL, forKey: widgetRefreshURLKey)
          } else {
            defaults.removeObject(forKey: widgetRefreshURLKey)
          }
          WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
          result(nil)
        case "clear":
          defaults.removeObject(forKey: widgetSnapshotKey)
          defaults.removeObject(forKey: widgetRefreshURLKey)
          WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
