import Flutter
import UIKit

// com.swiplelab.keyboard_height
// Streams keyboard height (logical points) and animation duration (ms) via the
// 'keyboard_height_event' EventChannel, matching the updated naming.
// Emits one event for open (final height) and one for close (height 0).
// iOS uses system-provided animation duration from keyboard notifications.

public class KeyboardHeightPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var isObserving = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    warmupKeyboard();
    let channel = FlutterEventChannel(name: "keyboard_height_event", binaryMessenger: registrar.messenger())
    let instance = KeyboardHeightPlugin()
    channel.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    startObserving()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
  }

  private func startObserving() {
    guard !isObserving else { return }
    isObserving = true
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
  }

  private func stopObserving() {
    guard isObserving else { return }
    isObserving = false
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
  }

  @objc private func keyboardWillChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
    let height = UIScreen.main.bounds.height - endFrame.origin.y
    let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
    let ms = Int(duration * 1000)
    eventSink?(["height": height, "duration": ms])
  }

  private static func warmupKeyboard() -> Void {
    let textField = UITextField(frame: .zero)
    let window = UIWindow()
    window.addSubview(textField)
    textField.becomeFirstResponder()
    textField.resignFirstResponder()
    window.isHidden = true
  }
}
