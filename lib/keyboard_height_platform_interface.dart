import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'keyboard_height_method_channel.dart';

abstract class KeyboardHeightPlatform extends PlatformInterface {
  KeyboardHeightPlatform() : super(token: _token);

  static final Object _token = Object();

  static KeyboardHeightPlatform _instance = MethodChannelKeyboardHeight();

  static KeyboardHeightPlatform get instance => _instance;

  static set instance(KeyboardHeightPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
