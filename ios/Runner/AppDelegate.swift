import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions)
    application.registerForRemoteNotifications()
    return didFinishLaunching
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GetPrioOnboarding")!
    let channel = FlutterMethodChannel(
      name: "getprio/onboarding", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      do {
        let directory = try FileManager.default.url(
          for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true)
          .appendingPathComponent("GetPrioInstallation", isDirectory: true)
        let marker = directory.appendingPathComponent("onboarding-completed")
        switch call.method {
        case "isComplete":
          result(FileManager.default.fileExists(atPath: marker.path))
        case "complete":
          try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
          // Unlike Keychain, this is deleted with the app. Do not migrate it
          // to another installation through an iCloud/device backup either.
          var excludedDirectory = directory
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try excludedDirectory.setResourceValues(values)
          try Data("1".utf8).write(to: marker, options: .atomic)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "onboarding_storage",
          message: "Could not save onboarding state", details: nil))
      }
    }
  }
}
