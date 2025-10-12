import 'dart:async';
import 'package:flutter/services.dart';
import 'package:keyboard_height/src/platform_interface/keyboard_height_platform_interface.dart';

class KeyboardHeightMobile extends KeyboardHeightPlatform {
  static const EventChannel _channel = EventChannel('keyboard_height_event');

  @override
  Stream<Map<String, dynamic>> keyboardHeightEventStream() {
    return _channel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event));
  }
}
