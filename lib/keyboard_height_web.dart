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
  // Use Safari-specific implementation if on Safari
  else if (_isSafari()) {
    stream = _safariStream();
  }
  // Fall back to generic implementation for other browsers
  else {
    stream = _fallbackStream();
  }

  return stream ?? const Stream.empty();
}

// Fallback implementation for browsers without Virtual Keyboard API or visualViewport
Stream<Map<String, dynamic>> _fallbackStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  double lastEmittedHeight = 0;
  double? initialWindowHeight;
  bool isInputFocused = false;
  Timer? periodicChecker;

  // Store initial viewport dimensions
  initialWindowHeight = web.window.innerHeight.toDouble();

  // Helper to calculate actual keyboard height accounting for viewport shift
  double calculateActualKeyboardHeight() {
    final currentWindowHeight = web.window.innerHeight.toDouble();

    // Check if viewport has been resized (typical mobile browser behavior)
    final viewportReduction = initialWindowHeight! - currentWindowHeight;

    // Check if the page has been scrolled up
    final scrollY = web.window.scrollY.toDouble();

    // The actual keyboard height is the viewport reduction minus any scroll offset
    // In cases where the viewport is pushed up, we want to report 0 or minimal height
    // since the content is already adjusted by the browser
    double keyboardHeight = 0;

    if (viewportReduction > 50 && isInputFocused) {
      // There's a significant viewport reduction and an input is focused
      // This likely means keyboard is open

      // Check if the page was scrolled to accommodate the keyboard
      // If scrollY > 0, the browser has shifted content up
      if (scrollY > 0) {
        // Browser has shifted content, so effective obstruction is less
        keyboardHeight = (viewportReduction - scrollY).clamp(0, viewportReduction);
      } else {
        // No scroll, full viewport reduction is the keyboard
        keyboardHeight = viewportReduction;
      }

      // Additional check: if document height changed, browser might be adjusting layout
      final currentDocHeight = web.document.body?.scrollHeight.toDouble() ?? 0;
      final windowHeight = web.window.innerHeight.toDouble();

      // If the document can be scrolled significantly, reduce reported height
      if (currentDocHeight > windowHeight * 1.5) {
        // Page is scrollable, browser will handle positioning
        keyboardHeight = keyboardHeight * 0.3; // Report only 30% to avoid double-compensation
      }
    }

    return keyboardHeight;
  }

  // Helper to start periodic checking for keyboard hide button
  void startPeriodicChecker() {
    periodicChecker?.cancel();

    // Check every 200ms while input is focused
    periodicChecker = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (!isInputFocused) {
        timer.cancel();
        return;
      }

      final keyboardHeight = calculateActualKeyboardHeight();

      // Detect any significant change in keyboard height
      // This handles both:
      // 1. Keyboard closed using hide button (height goes to 0)
      // 2. Keyboard re-opened by tapping already-focused input (height increases)
      if ((keyboardHeight - lastEmittedHeight).abs() > 10) {
        final opening = lastEmittedHeight == 0 && keyboardHeight > 0;
        final closing = lastEmittedHeight > 0 && keyboardHeight < 10;
        final duration = opening ? 250 : closing ? 200 : 150;

        lastEmittedHeight = keyboardHeight;
        controller.add({
          'height': keyboardHeight,
          'duration': duration,
        });
      }
    });
  }  

  // Listen for focus events on input elements
  web.window.addEventListener(
    'focusin',
    ((web.Event event) {
      final target = event.target;
      if (target != null &&
          (target.isA<web.HTMLInputElement>() ||
           target.isA<web.HTMLTextAreaElement>() ||
           (target.isA<web.Element>() && (target as web.Element).getAttribute('contenteditable') == 'true'))) {
        isInputFocused = true;

        // Wait a bit for keyboard to appear and viewport to adjust
        Future.delayed(Duration(milliseconds: 300), () {
          final keyboardHeight = calculateActualKeyboardHeight();

          if ((keyboardHeight - lastEmittedHeight).abs() > 10) {
            lastEmittedHeight = keyboardHeight;
            controller.add({
              'height': keyboardHeight,
              'duration': 250,
            });
          }

          // Start periodic checking to detect keyboard hide button
          startPeriodicChecker();
        });
      }
    }).toJS,
  );

  // Listen for blur events
  web.window.addEventListener(
    'focusout',
    ((web.Event event) {
      final target = event.target;
      if (target != null &&
          (target.isA<web.HTMLInputElement>() ||
           target.isA<web.HTMLTextAreaElement>() ||
           (target.isA<web.Element>() && (target as web.Element).getAttribute('contenteditable') == 'true'))) {
        isInputFocused = false;

        // Cancel periodic checker
        periodicChecker?.cancel();

        // Small delay to ensure keyboard starts closing
        Future.delayed(Duration(milliseconds: 100), () {
          if (!isInputFocused) {  // Double-check no other input was focused
            lastEmittedHeight = 0;
            controller.add({
              'height': 0.0,
              'duration': 200,
            });
          }
        });
      }
    }).toJS,
  );

  // Listen for window resize events as backup
  web.window.addEventListener(
    'resize',
    ((web.Event event) {
      // Immediate check for significant changes
      final keyboardHeight = calculateActualKeyboardHeight();

      // If keyboard was hidden (viewport restored), update immediately
      if (lastEmittedHeight > 0 && keyboardHeight < 10) {
        lastEmittedHeight = 0;
        controller.add({
          'height': 0.0,
          'duration': 200,
        });
      } else if (isInputFocused) {
        // Delay to let browser finish adjusting
        Future.delayed(Duration(milliseconds: 100), () {
          final keyboardHeight = calculateActualKeyboardHeight();

          if ((keyboardHeight - lastEmittedHeight).abs() > 10) {
            final opening = lastEmittedHeight == 0 && keyboardHeight > 0;
            final closing = lastEmittedHeight > 0 && keyboardHeight == 0;
            final duration = opening ? 250 : closing ? 200 : 150;

            lastEmittedHeight = keyboardHeight;
            controller.add({
              'height': keyboardHeight,
              'duration': duration,
            });
          }
        });
      }
    }).toJS,
  );

  // Listen for scroll events to detect viewport shifts
  web.window.addEventListener(
    'scroll',
    ((web.Event event) {
      if (isInputFocused && lastEmittedHeight > 0) {
        // Recalculate when scrolling with keyboard open
        final keyboardHeight = calculateActualKeyboardHeight();

        if ((keyboardHeight - lastEmittedHeight).abs() > 10) {
          lastEmittedHeight = keyboardHeight;
          controller.add({
            'height': keyboardHeight,
            'duration': 100,
          });
        }
      }
    }).toJS,
  );

  // Listen for click events on input elements to detect re-opening keyboard
  // This handles the case where input is already focused but keyboard was hidden
  web.window.addEventListener(
    'click',
    ((web.Event event) {
      final target = event.target;
      if (target != null &&
          (target.isA<web.HTMLInputElement>() ||
           target.isA<web.HTMLTextAreaElement>() ||
           (target.isA<web.Element>() && (target as web.Element).getAttribute('contenteditable') == 'true'))) {

        // If input is already focused and keyboard is hidden,
        // clicking it again should trigger keyboard detection
        if (isInputFocused && lastEmittedHeight == 0) {
          // Wait for keyboard to appear
          Future.delayed(Duration(milliseconds: 300), () {
            final keyboardHeight = calculateActualKeyboardHeight();

            if (keyboardHeight > 10) {
              lastEmittedHeight = keyboardHeight;
              controller.add({
                'height': keyboardHeight,
                'duration': 250,
              });
            }
          });
        }
      }
    }).toJS,
  );

  return controller.stream;
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
