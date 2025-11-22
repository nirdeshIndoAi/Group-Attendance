import Flutter
import UIKit

public class FaceRecognitionSdkPlugin: NSObject, FlutterPlugin {
  private let channelName = "face_recognition_sdk/native"
  private let nativeCore = FaceRecognitionNative.shared

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "face_recognition_sdk/native", binaryMessenger: registrar.messenger())
    let instance = FaceRecognitionSdkPlugin()
    let initResult = instance.nativeCore.initialize()
    if initResult != 0 {
      return
    }
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "compareTemplates":
      handleCompareTemplates(call: call, result: result)
    case "validateLicense":
      handleValidateLicense(call: call, result: result)
    case "verifyIntegrity":
      handleVerifyIntegrity(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCompareTemplates(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let template1Data = args["template1"] as? FlutterStandardTypedData,
      let template2Data = args["template2"] as? FlutterStandardTypedData
    else {
      result([
        "final": 0.0,
        "cosine": 0.0,
        "distance": 0.0,
        "exactMatch": 0.0,
        "correlation": 0.0,
      ])
      return
    }

    let metrics = nativeCore.compareTemplates(template1: template1Data.data, template2: template2Data.data)
    result(metrics)
  }

  private func handleValidateLicense(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let licenseKey = args["licenseKey"] as? String,
      let endpoint = args["endpoint"] as? String,
      let appId = args["appId"] as? String
    else {
      result(false)
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async {
          result(false)
        }
        return
      }
      
      let validationResult = self.nativeCore.validateLicense(licenseKey: licenseKey, appId: appId, endpoint: endpoint)
      DispatchQueue.main.async {
        result(validationResult == 0)
      }
    }
  }

  private func handleVerifyIntegrity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let challenge = args["challenge"] as? String
    else {
      result(nil)
      return
    }
    let signature = nativeCore.verifyIntegrity(challenge: challenge)
    result(signature)
  }

}

