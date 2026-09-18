import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let homeWidgetChannel = "com.codesoha.weathercare/home-widget"
  private let homeWidgetGroup = "group.com.codesoha.weathercare"
  private let homeWidgetSnapshotKey = "snapshot"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let widgetGroup = homeWidgetGroup
      let widgetSnapshotKey = homeWidgetSnapshotKey
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
          guard let snapshot = call.arguments as? String else {
            result(FlutterError(
              code: "INVALID_WIDGET_DATA",
              message: "위젯 자료가 비어 있습니다.",
              details: nil
            ))
            return
          }
          defaults.set(snapshot, forKey: widgetSnapshotKey)
          WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
          result(nil)
        case "clear":
          defaults.removeObject(forKey: widgetSnapshotKey)
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
