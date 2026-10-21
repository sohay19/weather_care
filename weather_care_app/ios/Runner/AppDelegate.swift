import Flutter
import FirebaseMessaging
import os
import StoreKit
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let homeWidgetChannel = "com.codesoha.weathercare/home-widget"
  private let homeWidgetGroup = "group.com.codesoha.weathercare"
  private let homeWidgetSnapshotKey = "snapshot"
  private let homeWidgetRefreshStatusKey = "refresh_status"
  private let homeWidgetRefreshURLKey = "refresh_url"
  private let homeWidgetTestAccessKey = "test_access_key"
  private let homeWidgetRevisionKey = "selection_revision"
  private let adRemovalChannel = "com.codesoha.weathercare/ad-removal"
  private let notificationDiagnosticsChannel = "com.codesoha.weathercare/notification-diagnostics"
  private let notificationLogger = Logger(
    subsystem: "com.codesoha.weathercare", category: "NotificationRegistration")
  private let homeWidgetGPSEnabledKey = "gps_enabled"
  private let backgroundLocation = BackgroundLocationMonitor()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    backgroundLocation.resume()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    Messaging.messaging().apnsToken = deviceToken
    notificationLogger.notice("WeatherCareNotification apns:registered")
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    notificationLogger.error("WeatherCareNotification apns:registration_failed:\((error as NSError).code, privacy: .public)")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let locationChannel = FlutterMethodChannel(
      name: "com.codesoha.weathercare/background-location",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    locationChannel.setMethodCallHandler { [weak self] call, result in
      self?.backgroundLocation.handle(call, result: result)
    }
    let diagnostics = FlutterMethodChannel(
      name: notificationDiagnosticsChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    diagnostics.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "record":
        guard let event = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.notificationLogger.notice("WeatherCareNotification \(event, privacy: .public)")
        result(nil)
      case "registerForRemoteNotifications":
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let purchaseChannel = FlutterMethodChannel(
      name: adRemovalChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    purchaseChannel.setMethodCallHandler { call, result in
      guard call.method == "hasActivePurchase",
            let productID = call.arguments as? String,
            !productID.isEmpty else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 15.0, *) {
        Task { @MainActor in
          for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let transaction) where transaction.productID == productID:
              result(true)
              return
            case .unverified(let transaction, _) where transaction.productID == productID:
              result(FlutterError(
                code: "PURCHASE_UNVERIFIED",
                message: "구매 상태를 확인하지 못했습니다.",
                details: nil
              ))
              return
            default:
              break
            }
          }
          result(false)
        }
      } else {
        result(FlutterError(
          code: "STOREKIT_UNAVAILABLE",
          message: "구매 상태 확인을 지원하지 않는 iOS 버전입니다.",
          details: nil
        ))
      }
    }
    let widgetGroup = homeWidgetGroup
    let widgetSnapshotKey = homeWidgetSnapshotKey
    let widgetRefreshStatusKey = homeWidgetRefreshStatusKey
    let widgetRefreshURLKey = homeWidgetRefreshURLKey
    let widgetTestAccessKey = homeWidgetTestAccessKey
    let widgetRevisionKey = homeWidgetRevisionKey
    let widgetGPSEnabledKey = homeWidgetGPSEnabledKey
    let channel = FlutterMethodChannel(
      name: homeWidgetChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
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
        let gpsEnabled = values?["gpsEnabled"] as? Bool ?? false
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let measuredAt = (values?["locationMeasuredAt"] as? String).flatMap { formatter.date(from: $0) }
        let storedAt = defaults.string(forKey: "location_measured_at").flatMap { formatter.date(from: $0) }
        if gpsEnabled, defaults.bool(forKey: widgetGPSEnabledKey), let storedAt,
           measuredAt == nil || storedAt > measuredAt! {
          result(nil)
          return
        }
        if gpsEnabled, let measuredAt {
          defaults.set(formatter.string(from: measuredAt), forKey: "location_measured_at")
        } else {
          defaults.removeObject(forKey: "location_measured_at")
        }
        defaults.set(UUID().uuidString, forKey: widgetRevisionKey)
        defaults.set(snapshot, forKey: widgetSnapshotKey)
        defaults.removeObject(forKey: widgetRefreshStatusKey)
        if let refreshURL = values?["refreshUrl"] as? String,
           !refreshURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          defaults.set(refreshURL, forKey: widgetRefreshURLKey)
        } else {
          defaults.removeObject(forKey: widgetRefreshURLKey)
        }
        defaults.set(values?["gpsEnabled"] as? Bool ?? false, forKey: widgetGPSEnabledKey)
        if let key = values?["testAccessKey"] as? String, !key.isEmpty {
          defaults.set(key, forKey: widgetTestAccessKey)
        } else {
          defaults.removeObject(forKey: widgetTestAccessKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
        result(nil)
      case "clear":
        defaults.set(UUID().uuidString, forKey: widgetRevisionKey)
        defaults.removeObject(forKey: widgetSnapshotKey)
        defaults.removeObject(forKey: widgetRefreshStatusKey)
        defaults.removeObject(forKey: widgetRefreshURLKey)
        defaults.removeObject(forKey: widgetTestAccessKey)
        defaults.removeObject(forKey: widgetGPSEnabledKey)
        defaults.removeObject(forKey: "location_measured_at")
        WidgetCenter.shared.reloadTimelines(ofKind: "WeatherCareWidget")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
