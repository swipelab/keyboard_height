import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:async';

import 'package:keyboard_height/src/keyboard_height_mobile.dart';

abstract class KeyboardHeightPlatform extends PlatformInterface {
  KeyboardHeightPlatform() : super(token: _token);

  static final Object _token = Object();

  static KeyboardHeightPlatform _instance = KeyboardHeightMobile();

  static KeyboardHeightPlatform get instance => _instance;

  static set instance(KeyboardHeightPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Map<String, dynamic>> keyboardHeightEventStream() {
    throw UnimplementedError(
        'keyboardHeightEventStream() has not been implemented.');
  }
}
