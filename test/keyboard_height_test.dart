import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_height/src/platform_interface/keyboard_height_platform_interface.dart';
import 'package:keyboard_height/src/keyboard_height_mobile.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockKeyboardHeightPlatform extends KeyboardHeightPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> keyboardHeightEventStream() {
    return _controller.stream;
  }

  void emitEvent(Map<String, dynamic> event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  final KeyboardHeightPlatform initialPlatform =
      KeyboardHeightPlatform.instance;

  test('$KeyboardHeightMobile is the default instance', () {
    expect(initialPlatform, isInstanceOf<KeyboardHeightMobile>());
  });

  test('keyboardHeightEventStream returns a stream', () {
    final fakePlatform = MockKeyboardHeightPlatform();
    KeyboardHeightPlatform.instance = fakePlatform;

    final stream = fakePlatform.keyboardHeightEventStream();
    expect(stream, isA<Stream<Map<String, dynamic>>>());

    fakePlatform.dispose();
  });

  test('keyboardHeightEventStream emits events', () async {
    final fakePlatform = MockKeyboardHeightPlatform();
    KeyboardHeightPlatform.instance = fakePlatform;

    final event = {'height': 300.0, 'duration': 250, 'open': true};

    expectLater(
      fakePlatform.keyboardHeightEventStream(),
      emits(event),
    );

    fakePlatform.emitEvent(event);

    fakePlatform.dispose();
  });
}
