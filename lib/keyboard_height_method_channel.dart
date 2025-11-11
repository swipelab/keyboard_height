import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'keyboard_height_platform_interface.dart';

/// An implementation of [KeyboardHeightPlatform] that uses method channels.
class MethodChannelKeyboardHeight extends KeyboardHeightPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('keyboard_height');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
