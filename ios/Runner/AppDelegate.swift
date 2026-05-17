import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeConfigChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    nativeConfigChannel = FlutterMethodChannel(
      name: "mentor_minds/native_config",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    nativeConfigChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result([
          "configured": false,
          "reason": "Native configuration is unavailable.",
        ])
        return
      }

      switch call.method {
      case "googleSignInStatus":
        result(self.googleSignInStatus())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func googleSignInStatus() -> [String: Any] {
    guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
      return [
        "configured": false,
        "reason": "Google Sign-In is not configured for iOS. Add GoogleService-Info.plist to the Runner target.",
      ]
    }

    guard let clientId = plist["CLIENT_ID"] as? String, !clientId.isEmpty else {
      return [
        "configured": false,
        "reason": "Google Sign-In is not configured for iOS. The current GoogleService-Info.plist is missing CLIENT_ID.",
      ]
    }

    guard let reversedClientId = plist["REVERSED_CLIENT_ID"] as? String,
          !reversedClientId.isEmpty else {
      return [
        "configured": false,
        "reason": "Google Sign-In is not configured for iOS. The current GoogleService-Info.plist is missing REVERSED_CLIENT_ID.",
      ]
    }

    let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
    let configuredSchemes = urlTypes
      .compactMap { $0["CFBundleURLSchemes"] as? [String] }
      .flatMap { $0 }

    guard configuredSchemes.contains(reversedClientId) else {
      return [
        "configured": false,
        "reason": "Google Sign-In is not configured for iOS. Add the REVERSED_CLIENT_ID URL scheme to Info.plist.",
      ]
    }

    return [
      "configured": true,
      "clientId": clientId,
    ]
  }
}
