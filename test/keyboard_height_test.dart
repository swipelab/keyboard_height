import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_height/keyboard_height.dart';
import 'package:keyboard_height/keyboard_height_platform_interface.dart';
import 'package:keyboard_height/keyboard_height_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockKeyboardHeightPlatform
    with MockPlatformInterfaceMixin
    implements KeyboardHeightPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final KeyboardHeightPlatform initialPlatform =
      KeyboardHeightPlatform.instance;

  test('$MethodChannelKeyboardHeight is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelKeyboardHeight>());
  });

  test('getPlatformVersion', () async {
    KeyboardHeight keyboardHeightPlugin = KeyboardHeight();
    MockKeyboardHeightPlatform fakePlatform = MockKeyboardHeightPlatform();
    KeyboardHeightPlatform.instance = fakePlatform;

    expect(await keyboardHeightPlugin.getPlatformVersion(), '42');
  });
}
