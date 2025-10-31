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

  // Check if we're on Android Chrome
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAndroidChrome = userAgent.contains('android') && userAgent.contains('chrome');

  // For Android Chrome, prefer visualViewport due to Virtual Keyboard API issues
  // The API sometimes reports double height or physical pixels instead of CSS pixels
  if (isAndroidChrome) {
    return _visualViewportStream();
  }

  // Use Virtual Keyboard API for desktop Chrome/Firefox if available
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
  DateTime? lastEventTime;

  // Check if we're on Android
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAndroid = userAgent.contains('android');

  // Get device pixel ratio for Android Chrome
  final devicePixelRatio = web.window.devicePixelRatio;

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
          // Debounce rapid successive events (Android Chrome sometimes fires multiple)
          final now = DateTime.now();
          if (lastEventTime != null &&
              now.difference(lastEventTime!).inMilliseconds < 50) {
            return; // Skip rapid successive events
          }
          lastEventTime = now;

          // Get the keyboard rect from the event
          final boundingRect = event['boundingRect'] as JSObject?;

          double keyboardHeight = 0;
          if (boundingRect != null) {
            final height = boundingRect['height'];
            if (height != null) {
              keyboardHeight = (height as JSNumber).toDartDouble;

              // Android Chrome specific fix: Check if height needs adjustment
              // The Virtual Keyboard API should return CSS pixels, but on some Android
              // devices it might return physical pixels
              if (isAndroid && devicePixelRatio > 1) {
                // Check if the height seems unreasonably large (likely in physical pixels)
                // Compare with viewport height to detect if conversion is needed
                final viewportHeight = web.window.innerHeight.toDouble();
                if (keyboardHeight > viewportHeight * 0.7) {
                  // Height is suspiciously large, likely in physical pixels
                  keyboardHeight = keyboardHeight / devicePixelRatio;
                }
              }
            }
          }

          // Additional sanity check: keyboard shouldn't be more than 60% of viewport
          final maxReasonableHeight = web.window.innerHeight * 0.6;
          if (keyboardHeight > maxReasonableHeight) {
            // Fall back to visualViewport method if height is unreasonable
            print('Virtual Keyboard API returned unreasonable height: $keyboardHeight');
            controller.close();
            return;
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
  bool hasEstablishedBaseline = false;

  // Check if we're on Android
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAndroid = userAgent.contains('android');

  // Initialize baseline with current viewport height
  // This should be the height without keyboard
  if (web.window.visualViewport != null) {
    baselineHeight = web.window.visualViewport!.height.toDouble();
    // On Android, use the window inner height as initial baseline
    // as it's more stable than visualViewport
    if (isAndroid) {
      baselineHeight = web.window.innerHeight.toDouble();
    }
    hasEstablishedBaseline = true;
  }

  web.window.visualViewport?.addEventListener(
      'resize',
      ((web.Event event) {
        final vv = web.window.visualViewport;
        if (vv == null) return;

        final currentHeight = vv.height.toDouble();

        // For Android, be more conservative about updating baseline
        if (isAndroid && hasEstablishedBaseline) {
          // Only update baseline if:
          // 1. Current height is larger (keyboard closing)
          // 2. AND the difference is significant (> 100px)
          // 3. AND we previously detected a keyboard (lastEmittedHeight > 0)
          if (currentHeight > (baselineHeight ?? 0) &&
              (currentHeight - (baselineHeight ?? 0)) > 100 &&
              lastEmittedHeight > 0) {
            baselineHeight = currentHeight;
          }
        } else if (!isAndroid) {
          // Original logic for non-Android devices
          if (baselineHeight == null || currentHeight > (baselineHeight ?? 0)) {
            baselineHeight = currentHeight;
          }
        }

        // Use the established baseline
        final base = baselineHeight ?? currentHeight;
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

  // For Android, also reset baseline on focus to prevent accumulation
  if (isAndroid) {
    web.window.addEventListener(
        'focusin',
        ((web.Event event) {
          final target = event.target;
          if (target.isA<web.HTMLInputElement>() ||
              target.isA<web.HTMLTextAreaElement>()) {
            // Reset baseline when focusing an input
            // Use a small delay to let the viewport settle
            Future.delayed(const Duration(milliseconds: 100), () {
              if (web.window.visualViewport != null && lastEmittedHeight == 0) {
                // Only reset if keyboard is not currently shown
                baselineHeight = web.window.innerHeight.toDouble();
              }
            });
          }
        }).toJS);
  }

  return controller.stream;
}
