#include "include/keyboard_height/keyboard_height_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "keyboard_height_plugin.h"

void KeyboardHeightPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  keyboard_height::KeyboardHeightPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
