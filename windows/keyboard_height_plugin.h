#ifndef FLUTTER_PLUGIN_KEYBOARD_HEIGHT_PLUGIN_H_
#define FLUTTER_PLUGIN_KEYBOARD_HEIGHT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace keyboard_height {

class KeyboardHeightPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  KeyboardHeightPlugin();

  virtual ~KeyboardHeightPlugin();

  // Disallow copy and assign.
  KeyboardHeightPlugin(const KeyboardHeightPlugin&) = delete;
  KeyboardHeightPlugin& operator=(const KeyboardHeightPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace keyboard_height

#endif  // FLUTTER_PLUGIN_KEYBOARD_HEIGHT_PLUGIN_H_
