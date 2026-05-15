import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "go_puzzle/model_assets",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "modelPath" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let args = call.arguments as? [String: Any],
          let fileName = args["fileName"] as? String
        else {
          result(FlutterError(
            code: "BAD_ARGS",
            message: "Missing model fileName",
            details: nil
          ))
          return
        }
        let url = URL(fileURLWithPath: fileName)
        let resource = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        guard let path = Bundle.main.path(forResource: resource, ofType: ext) else {
          result(FlutterError(
            code: "MODEL_NOT_FOUND",
            message: "Bundled model not found: \(fileName)",
            details: nil
          ))
          return
        }
        result(path)
      }
      TerritoryOnnxChannel.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
