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

  final isSafari = _isSafari();


  if (isSafari) {
    return _safariStream();
  }

  // Use Virtual Keyboard API for desktop Chrome/Firefox if available
  if (_supportsVirtualKeyboardAPI()) {
    return _virtualKeyboardAPIStream();
  }

  //  // Check browser type
  // final userAgent = web.window.navigator.userAgent.toLowerCase();
  // final isAndroidChrome = userAgent.contains('android') && userAgent.contains('chrome');
  //  // Route to appropriate implementation
  // if (isAndroidChrome) {
  //   return _androidChromeStream();
  // }


  // Fall back to generic implementation
  return _fallbackStream();
}

// Virtual Keyboard API implementation for Chrome/Firefox
Stream<Map<String, dynamic>> _virtualKeyboardAPIStream() {
  print('virtual keyboard stream');
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  double previousHeight = 0;
  DateTime? lastEventTime;
  int eventCount = 0;

  // Check if we're on Android
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAndroid = userAgent.contains('android');

  // Get device pixel ratio for Android Chrome
  final devicePixelRatio = web.window.devicePixelRatio;

  // For Android, use fallback stream instead due to Virtual Keyboard API issues
  if (isAndroid) {
    print('Android detected, using fallback stream instead of Virtual Keyboard API');
    return _fallbackStream();
  }

  // Enable the Virtual Keyboard API overlay
  try {
    final navigatorJs = web.window.navigator as JSObject;
    final virtualKeyboard = navigatorJs['virtualKeyboard'] as JSObject?;
    if (virtualKeyboard != null) {
      virtualKeyboard['overlaysContent'] = true.toJS;
    }
  } catch (e) {
    // If we can't enable overlay, fall back to generic implementation
    return _fallbackStream();
  }

  // Listen to geometrychange event
  try {
    final navigatorJs = web.window.navigator as JSObject;
    final virtualKeyboard = navigatorJs['virtualKeyboard'] as JSObject?;

    if (virtualKeyboard != null) {
      virtualKeyboard.callMethod('addEventListener'.toJS,
        'geometrychange'.toJS,
        ((JSObject event) {
          eventCount++;

          // Debounce rapid successive events
          final now = DateTime.now();
          if (lastEventTime != null &&
              now.difference(lastEventTime!).inMilliseconds < 100) {
            print('Skipping rapid event #$eventCount (within 100ms)');
            return;
          }
          lastEventTime = now;

          // Get the keyboard rect from the event
          final boundingRect = event['boundingRect'] as JSObject?;

          double keyboardHeight = 0;
          double rawHeight = 0;

          if (boundingRect != null) {
            final height = boundingRect['height'];
            if (height != null) {
              rawHeight = (height as JSNumber).toDartDouble;
              keyboardHeight = rawHeight;

              // Debug logging
              final viewportHeight = web.window.innerHeight.toDouble();
              final visualViewportHeight = web.window.visualViewport?.height.toDouble() ?? 0;
              print('Event #$eventCount: rawHeight=$rawHeight, windowHeight=$viewportHeight, visualViewportHeight=$visualViewportHeight, devicePixelRatio=$devicePixelRatio');
            }
          }

          // Additional sanity check: keyboard shouldn't be more than 60% of viewport
          final maxReasonableHeight = web.window.innerHeight * 0.6;
          if (keyboardHeight > maxReasonableHeight) {
            print('Height unreasonable: $keyboardHeight > $maxReasonableHeight (60% of viewport)');
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

            print('Emitting height change: $previousHeight -> $keyboardHeight (opening=$opening, closing=$closing)');
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
    print('Error setting up Virtual Keyboard API: $e');
    // If we can't add the event listener, fall back to generic implementation
    return _fallbackStream();
  }

  return controller.stream;
}

// Specialized implementation for Android Chrome
Stream<Map<String, dynamic>> _androidChromeStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  double lastEmittedHeight = 0;
  Timer? debounceTimer;

  // Track focus state
  bool isInputFocused = false;

  // Listen to focus events to track input state
  web.window.addEventListener(
      'focusin',
      ((web.Event event) {
        final target = event.target;
        if (target.isA<web.HTMLInputElement>() ||
            target.isA<web.HTMLTextAreaElement>()) {
          isInputFocused = true;
        }
      }).toJS);

  web.window.addEventListener(
      'focusout',
      ((web.Event event) {
        final target = event.target;
        if (target.isA<web.HTMLInputElement>() ||
            target.isA<web.HTMLTextAreaElement>()) {
          isInputFocused = false;
          // Immediately emit 0 height when input loses focus
          if (lastEmittedHeight > 0) {
            lastEmittedHeight = 0;
            controller.add({
              'height': 0.0,
              'duration': 200,
            });
          }
        }
      }).toJS);

  // Use both visualViewport and window resize events for Android
  void checkKeyboardHeight() {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final vv = web.window.visualViewport;
      if (vv == null) return;

      final visualViewportHeight = vv.height.toDouble();
      final windowHeight = web.window.innerHeight.toDouble();

      // Calculate keyboard height as difference between window and visual viewport
      // This is more reliable on Android than trying to track baseline
      double keyboardHeight = 0;

      if (isInputFocused) {
        // When input is focused, calculate keyboard height
        // The keyboard height is the difference between window height and visual viewport
        final heightDiff = windowHeight - visualViewportHeight;

        // Only consider it a keyboard if the difference is significant
        if (heightDiff > 40) {
          keyboardHeight = heightDiff;

          // Sanity check - keyboard shouldn't be more than 50% of window height
          if (keyboardHeight > windowHeight * 0.5) {
            keyboardHeight = windowHeight * 0.5;
          }
        }
      }

      // Only emit if there's a meaningful change
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
    });
  }

  // Listen to visualViewport resize if available, otherwise window resize
  if (web.window.visualViewport != null) {
    web.window.visualViewport!.addEventListener(
        'resize',
        ((web.Event event) {
          checkKeyboardHeight();
        }).toJS);
  } else {
    // Fallback to window resize if visualViewport is not available
    web.window.addEventListener(
        'resize',
        ((web.Event event) {
          checkKeyboardHeight();
        }).toJS);
  }

  return controller.stream;
}

// Safari-specific implementation with focusout workaround
Stream<Map<String, dynamic>> _safariStream() {
  print('safari stream');
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

// Generic fallback implementation for other browsers
Stream<Map<String, dynamic>> _fallbackStream() {
  print('fallback keyboard stream');
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  // Check if we're on Android
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAndroid = userAgent.contains('android');

  double? baselineHeight;
  double lastEmittedHeight = 0;
  Timer? stabilizationTimer;
  bool isStabilizing = false;

  // Initialize baseline with current height
  if (web.window.visualViewport != null) {
    baselineHeight = web.window.visualViewport!.height.toDouble();
    print('Initial baseline height: $baselineHeight');
  } else {
    baselineHeight = web.window.innerHeight.toDouble();
    print('Initial baseline height (window): $baselineHeight');
  }

  // Try visualViewport first, fallback to window resize
  if (web.window.visualViewport != null) {
    web.window.visualViewport!.addEventListener(
        'resize',
        ((web.Event event) {
          final vv = web.window.visualViewport!;
          final currentHeight = vv.height.toDouble();
          final windowHeight = web.window.innerHeight.toDouble();

          print('visualViewport resize: current=$currentHeight, baseline=$baselineHeight, window=$windowHeight');

          // For Android, use a more conservative baseline update strategy
          if (isAndroid) {
            // Cancel any pending stabilization
            stabilizationTimer?.cancel();

            // Only update baseline when:
            // 1. We don't have a baseline yet
            // 2. OR the height increased significantly (keyboard closing) AND we're not in a transition
            if (baselineHeight == null) {
              baselineHeight = currentHeight;
              print('Setting initial baseline: $baselineHeight');
            } else if (!isStabilizing &&
                       currentHeight > baselineHeight! + 50 &&
                       lastEmittedHeight > 0) {
              // Keyboard seems to be closing, but wait for stabilization
              isStabilizing = true;
              stabilizationTimer = Timer(const Duration(milliseconds: 300), () {
                // After stabilization, check if we should update baseline
                final stabilizedHeight = web.window.visualViewport?.height.toDouble() ?? currentHeight;
                if (stabilizedHeight > baselineHeight! && lastEmittedHeight == 0) {
                  baselineHeight = stabilizedHeight;
                  print('Baseline updated after stabilization: $baselineHeight');
                }
                isStabilizing = false;
              });
            }

            // Use the established baseline for calculation
            final obscured = ((baselineHeight ?? currentHeight) - currentHeight).clamp(0.0, baselineHeight ?? currentHeight);
            final isKeyboardLikely = obscured > 40;
            final keyboardHeight = isKeyboardLikely ? obscured : 0.0;

            print('Android calculation: obscured=$obscured, keyboardHeight=$keyboardHeight');

            // Only emit if there's a meaningful change
            if ((keyboardHeight - lastEmittedHeight).abs() > 5) {
              final opening = lastEmittedHeight == 0 && keyboardHeight > 0;
              final closing = lastEmittedHeight > 0 && keyboardHeight == 0;
              final duration = opening
                  ? 250
                  : closing
                      ? 200
                      : 150;

              print('Emitting height: $keyboardHeight (was: $lastEmittedHeight)');
              lastEmittedHeight = keyboardHeight;
              controller.add({
                'height': keyboardHeight,
                'duration': duration,
              });
            }
          } else {
            // Original logic for non-Android
            if (baselineHeight == null || currentHeight > (baselineHeight ?? 0)) {
              baselineHeight = currentHeight;
            }
            final base = (baselineHeight ?? currentHeight).toDouble();
            final obscured = (base - currentHeight).clamp(0, base);

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
          }
        }).toJS);
  } else {
    // Fallback: Monitor window resize for browsers without visualViewport
    web.window.addEventListener(
        'resize',
        ((web.Event event) {
          final currentHeight = web.window.innerHeight.toDouble();

          // Initialize baseline
          if (baselineHeight == null || currentHeight > (baselineHeight ?? 0)) {
            baselineHeight = currentHeight;
          }

          final obscured = (baselineHeight! - currentHeight).clamp(0, baselineHeight!);
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
  }

  return controller.stream;
}
