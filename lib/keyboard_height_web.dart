import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:keyboard_height/src/platform_interface/keyboard_height_platform_interface.dart';
import 'package:web/web.dart' as web;

class KeyboardHeightWeb extends KeyboardHeightPlatform {
  static void registerWith(Registrar registrar) {
    KeyboardHeightPlatform.instance = KeyboardHeightWeb();
  }

  @override
  Stream<Map<String, dynamic>> keyboardHeightEventStream() {
    return _keyboardHeightEventStream();
  }
}

// Browser detection helper
bool _isSafari() {
  final vendor = web.window.navigator.vendor;
  final userAgent = web.window.navigator.userAgent;
  return vendor.contains('Apple') && !userAgent.contains('CriOS') && !userAgent.contains('FxiOS');
}

bool _supportsVirtualKeyboardAPI() {
  // Check if virtualKeyboard API is available
  try {
    final navigatorJs = web.window.navigator as JSObject;
    return navigatorJs.has('virtualKeyboard');
  } catch (e) {
    return false;
  }
}

Stream<Map<String, dynamic>> _keyboardHeightEventStream() {
  // This check is to prevent execution on non-web platforms.
  try {
    final _ = web.window;
  } catch (_) {
    return const Stream.empty();
  }

  Stream<Map<String, dynamic>>? stream;
  // Use Virtual Keyboard API if available
  if (_supportsVirtualKeyboardAPI()) {
    stream = _virtualKeyboardAPIStream();
  }

  if (stream == null && _isSafari()) {
    stream = _safariStream();
  }

  return stream ?? _fallbackStream();
}

Stream<Map<String, dynamic>> _fallbackStream() {
  //TODO: implement
  return const Stream.empty();
}

// Virtual Keyboard API implementation for Chrome/Firefox
Stream<Map<String, dynamic>>? _virtualKeyboardAPIStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  double previousHeight = 0;

  // Enable the Virtual Keyboard API overlay
  try {
    final navigatorJs = web.window.navigator as JSObject;
    final virtualKeyboard = navigatorJs['virtualKeyboard'] as JSObject?;
    if (virtualKeyboard != null) {
      virtualKeyboard['overlaysContent'] = true.toJS;
    }
  } catch (e) {
    // If we can't enable overlay, fall back to generic implementation
    return null;
  }

  // Listen to geometrychange event
  try {
    final navigatorJs = web.window.navigator as JSObject;
    final virtualKeyboard = navigatorJs['virtualKeyboard'] as JSObject?;

    if (virtualKeyboard != null) {
      virtualKeyboard.callMethod('addEventListener'.toJS,
        'geometrychange'.toJS,
        ((JSObject event) {

          // Get the keyboard rect from the event
          final boundingRect = event['boundingRect'] as JSObject?;

          double keyboardHeight = 0;
          double rawHeight = 0;

          if (boundingRect != null) {
            final height = boundingRect['height'];
            if (height != null) {
              rawHeight = (height as JSNumber).toDartDouble;
              keyboardHeight = rawHeight;
            }
          }

          // Additional sanity check: keyboard shouldn't be more than 60% of viewport
          final maxReasonableHeight = web.window.innerHeight * 0.6;
          if (keyboardHeight > maxReasonableHeight) {
            // Don't return, just clamp it
            keyboardHeight = maxReasonableHeight;
          }

          // Only emit if there's an actual change
          if ((keyboardHeight - previousHeight).abs() > 0.5) {
            final opening = previousHeight == 0 && keyboardHeight > 0;
            final closing = previousHeight > 0 && keyboardHeight == 0;
            final duration = opening
                ? 250
                : closing
                    ? 200
                    : 150;

            previousHeight = keyboardHeight;
            controller.add({
              'height': keyboardHeight,
              'duration': duration,
            });
          }
        }).toJS
      );
    }
  } catch (e) {
    null;
  }

  return controller.stream;
}

// Safari-specific implementation with focusout workaround
Stream<Map<String, dynamic>> _safariStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  double? baselineHeight; // visualViewport height when keyboard closed
  double lastEmittedHeight = 0;

  // Use visualViewport for Safari if available
  if (web.window.visualViewport != null) {
    web.window.visualViewport!.addEventListener(
        'resize',
        ((web.Event event) {
          final vv = web.window.visualViewport!;
          final currentHeight = vv.height.toDouble();

          // Establish baseline (largest observed height) when no keyboard.
          if (baselineHeight == null || currentHeight > (baselineHeight ?? 0)) {
            baselineHeight = currentHeight;
          }
          final base = (baselineHeight ?? currentHeight).toDouble();
          final obscured = (base - currentHeight).clamp(0, base);

          // Heuristic filter: ignore tiny changes (< 40 logical px)
          final isKeyboardLikely = obscured > 40;
          final keyboardHeight = (isKeyboardLikely ? obscured : 0).toDouble();

          if ((keyboardHeight - lastEmittedHeight).abs() > 1) {
            final opening = lastEmittedHeight == 0 && keyboardHeight > 0;
            final closing = lastEmittedHeight > 0 && keyboardHeight == 0;
            final duration = opening
                ? 250
                : closing
                    ? 200
                    : 150;
            lastEmittedHeight = keyboardHeight;
            controller.add({
              'height': keyboardHeight,
              'duration': duration,
            });
          }
        }).toJS);

    // On Safari, the 'resize' event for keyboard closing is delayed.
    // We can listen to 'focusout' on input elements to anticipate it.
    web.window.addEventListener(
        'focusout',
        ((web.Event event) {
          final target = event.target;
          if (target.isA<web.HTMLInputElement>() ||
              target.isA<web.HTMLTextAreaElement>()) {
            if (lastEmittedHeight > 0) {
              lastEmittedHeight = 0;
              controller.add({
                'height': 0.0,
                'duration': 200,
              });
            }
          }
        }).toJS);
  }

  return controller.stream;
}
