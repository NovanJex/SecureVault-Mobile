import UIKit
import Flutter
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.securevault.app/native",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getAppDataDir":
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("SecureVault")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        result(dir.path)

      case "setPrivacyScreen":
        result(nil)

      case "authenticateBiometric":
        let context = LAContext()
        var error: NSError?
        let reason = (call.arguments as? [String: Any])?["reason"] as? String ?? "解锁 SecureVault"
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
          context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
              result(success)
            }
          }
        } else {
          result(true)
        }

      case "saveHardwareMasterKey":
        let key = (call.arguments as? [String: Any])?["masterKey"] as? String ?? ""
        UserDefaults.standard.set(key, forKey: "sv_se_master_key")
        result(nil)

      case "loadHardwareMasterKey":
        result(UserDefaults.standard.string(forKey: "sv_se_master_key"))

      case "clearHardwareMasterKey":
        UserDefaults.standard.removeObject(forKey: "sv_se_master_key")
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
