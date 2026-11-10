import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 热状态通道:返回 ProcessInfo.thermalState
    // 0 = nominal, 1 = fair, 2 = serious, 3 = critical
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "battery_guard/thermal",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "getThermalState" else {
          result(FlutterMethodNotImplemented)
          return
        }
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: result(0)
        case .fair: result(1)
        case .serious: result(2)
        case .critical: result(3)
        @unknown default: result(0)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
