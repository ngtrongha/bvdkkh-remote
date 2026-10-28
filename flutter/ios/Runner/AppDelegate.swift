// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var supportNotificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    dummyMethodToEnforceBundling();
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureSupportNotifications()
    UNUserNotificationCenter.current().delegate = self
    return launched
  }

  private func configureSupportNotifications() {
    guard let registrar = registrar(forPlugin: "BVDKKHSupportNotifications") else {
      NSLog("Cannot register support notification channel: Flutter engine is unavailable")
      return
    }
    let channel = FlutterMethodChannel(
      name: "bvdkkh/support_notifications",
      binaryMessenger: registrar.messenger()
    )
    supportNotificationChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "Notification handler is unavailable", details: nil))
        return
      }
      switch call.method {
      case "requestPermission":
        self.requestSupportNotificationPermission(result)
      case "show":
        self.showSupportNotification(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func supportNotificationsPermitted(_ settings: UNNotificationSettings) -> Bool {
    let authorized = settings.authorizationStatus == .authorized
      || settings.authorizationStatus == .provisional
      || settings.authorizationStatus == .ephemeral
    return authorized && (settings.alertSetting == .enabled
      || settings.notificationCenterSetting == .enabled
      || settings.lockScreenSetting == .enabled)
  }

  private func requestSupportNotificationPermission(_ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      if settings.authorizationStatus != .notDetermined {
        DispatchQueue.main.async { result(self.supportNotificationsPermitted(settings)) }
        return
      }
      center.requestAuthorization(options: [.alert, .sound]) { _, error in
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(code: "notification_permission_failed", message: error.localizedDescription, details: nil))
          }
          return
        }
        center.getNotificationSettings { updatedSettings in
          DispatchQueue.main.async { result(self.supportNotificationsPermitted(updatedSettings)) }
        }
      }
    }
  }

  private func showSupportNotification(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any],
      let id = arguments["id"] as? Int, id > 0,
      let title = arguments["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let body = arguments["body"] as? String,
      let sound = arguments["sound"] as? Bool else {
      result(FlutterError(code: "invalid_notification", message: "Expected a positive id, title, body and sound flag", details: nil))
      return
    }
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard self.supportNotificationsPermitted(settings) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "notifications_disabled", message: "Enable notifications for BVĐKKH - Remote in iOS Settings", details: nil))
        }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      if sound && settings.soundSetting == .enabled {
        content.sound = .default
      }
      let request = UNNotificationRequest(
        identifier: "bvdkkh-support-\(id)", content: content, trigger: nil
      )
      center.add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "notification_failed", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("bvdkkh-support-") {
      var options: UNNotificationPresentationOptions = [.banner, .list]
      if notification.request.content.sound != nil {
        options.insert(.sound)
      }
      completionHandler(options)
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier.hasPrefix("bvdkkh-support-") {
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
    
  public func dummyMethodToEnforceBundling() {
      dummy_method_to_enforce_bundling();
    session_get_rgba(nil, 0);
  }
}
