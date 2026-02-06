import UIKit
import Flutter
import FirebaseCore
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Only disable app verification in DEBUG builds for test phone numbers
    // In release builds, real verification (reCAPTCHA or APNs) will be used
    #if DEBUG
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    #endif

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle URL callback for Firebase Auth (reCAPTCHA)
  override func application(_ app: UIApplication,
                          open url: URL,
                          options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
