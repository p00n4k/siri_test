import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    let siriShortcutChannel = "siri_shortcut"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: siriShortcutChannel, binaryMessenger: controller.binaryMessenger)

        methodChannel.setMethodCallHandler { (call, result) in
            if call.method == "invokePM25Intent" {
                if let url = URL(string: "shortcuts://run-shortcut?name=Check%20PM2.5%20Level") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    result(nil)
                } else {
                    result(FlutterError(code: "ERROR", message: "Failed to open Siri Shortcut", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return true
    }
}
