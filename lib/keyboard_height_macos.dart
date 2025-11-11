import 'package:keyboard_height/src/keyboard_height_desktop.dart';

class KeyboardHeightPlugin extends KeyboardHeightDesktop {
  static void registerWith() {
    KeyboardHeightDesktop.register();
  }
}
