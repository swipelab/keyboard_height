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

  // Use Virtual Keyboard API for Chrome/Firefox if available
  if (!_isSafari() && _supportsVirtualKeyboardAPI()) {
    return _virtualKeyboardAPIStream();
  }

  // Fall back to visualViewport method for Safari and browsers without Virtual Keyboard API
  return _visualViewportStream();
}

// Virtual Keyboard API implementation for Chrome/Firefox
Stream<Map<String, dynamic>> _virtualKeyboardAPIStream() {
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
    // If we can't enable overlay, fall back to visualViewport
    return _visualViewportStream();
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
          if (boundingRect != null) {
            final height = boundingRect['height'];
            if (height != null) {
              keyboardHeight = (height as JSNumber).toDartDouble;
            }
          }

          // For Chrome/Firefox, emit all changes directly from the Virtual Keyboard API
          // No filtering needed as the API provides accurate measurements
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
        }).toJS
      );
    }
  } catch (e) {
    // If we can't add the event listener, fall back to visualViewport
    return _visualViewportStream();
  }

  return controller.stream;
}

// Original visualViewport implementation for Safari and fallback
Stream<Map<String, dynamic>> _visualViewportStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  double? baselineHeight; // visualViewport height when keyboard closed
  double lastEmittedHeight = 0;

  web.window.visualViewport?.addEventListener(
      'resize',
      ((web.Event event) {
        final vv = web.window.visualViewport;
        if (vv == null) return;

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
                  : 150; // mid adjustments if any
          lastEmittedHeight = keyboardHeight;
          controller.add({
            'height': keyboardHeight,
            'duration': duration,
          });
        }
      }).toJS);

  // On Safari, the 'resize' event for keyboard closing is delayed.
  // We can listen to 'focusout' on input elements to anticipate it.
  if (_isSafari()) {
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
