import 'dart:async';
import 'dart:js_interop';
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

Stream<Map<String, dynamic>> _keyboardHeightEventStream() {
  // This check is to prevent execution on non-web platforms.
  try {
    final _ = web.window;
  } catch (_) {
    return const Stream.empty();
  }

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
  web.window.addEventListener(
      'focusout',
      ((web.Event event) {
        final vendor = web.window.navigator.vendor;
        final isSafari = vendor.contains('Apple');
        if (!isSafari) return;

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

  return controller.stream;
}
