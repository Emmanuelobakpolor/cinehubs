import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    makeWindowSecure()
    return result
  }

  // Prevents screenshots and screen recordings by nesting the window layer
  // inside a UITextField's secure input layer (which iOS cannot capture).
  private func makeWindowSecure() {
    guard let window = UIApplication.shared.windows.first else { return }
    let secureField = UITextField()
    secureField.isSecureTextEntry = true
    secureField.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(secureField)
    secureField.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    secureField.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    window.layer.superlayer?.addSublayer(secureField.layer)
    secureField.layer.sublayers?.last?.addSublayer(window.layer)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
