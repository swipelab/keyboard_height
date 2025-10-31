import 'dart:async';
import 'package:keyboard_height/src/platform_interface/keyboard_height_platform_interface.dart';

class KeyboardHeightDesktop extends KeyboardHeightPlatform {
  static void register() {
    KeyboardHeightPlatform.instance = KeyboardHeightDesktop();
  }

  @override
  Stream<Map<String, dynamic>> keyboardHeightEventStream() {
    return const Stream.empty();
  }
}
