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
  double? windowHeight; // Track window height for resize detection
  DateTime? lastResizeTime; // Track timing to debounce resize events
  
  void updateKeyboardHeight() {
    final vv = web.window.visualViewport;
    if (vv == null) return;

    final currentHeight = vv.height.toDouble();
    final currentWindowHeight = web.window.innerHeight.toDouble();
    final now = DateTime.now();
    
    // Detect window resize by comparing current window height with stored value
    final isWindowResize = windowHeight != null && 
        (currentWindowHeight - windowHeight!).abs() > 10;
    
    // Reset baseline on window resize to prevent invalid calculations
    if (isWindowResize) {
      baselineHeight = currentHeight;
      windowHeight = currentWindowHeight;
      lastResizeTime = now;
      
      // If we had keyboard open and window resized, close the keyboard
      if (lastEmittedHeight > 0) {
        lastEmittedHeight = 0;
        controller.add({
          'height': 0.0,
          'duration': 200,
        });
      }
      return;
    }
    
    // Initialize window height tracking
    if (windowHeight == null) {
      windowHeight = currentWindowHeight;
    }
    
    // Debounce rapid resize events (within 100ms of window resize)
    if (lastResizeTime != null && 
        now.difference(lastResizeTime!).inMilliseconds < 100) {
      return;
    }

    // Establish baseline, but be more conservative about updates
    // Only update baseline if significantly larger or if baseline is null
    if (baselineHeight == null) {
      baselineHeight = currentHeight;
    } else if (currentHeight > baselineHeight! + 20) {
      // Only update baseline if new height is significantly larger
      // This prevents baseline drift from small variations
      baselineHeight = currentHeight;
    }
    
    final base = (baselineHeight ?? currentHeight).toDouble();
    final obscured = (base - currentHeight).clamp(0, base);

    // Improved heuristic: Consider screen size for threshold
    final screenHeight = web.window.screen.height.toDouble();
    final minThreshold = (screenHeight * 0.05).clamp(30, 60); // 5% of screen height, min 30px, max 60px
    final isKeyboardLikely = obscured > minThreshold;
    final keyboardHeight = (isKeyboardLikely ? obscured : 0).toDouble();

    // Only emit changes that are significant enough
    if ((keyboardHeight - lastEmittedHeight).abs() > 5) {
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
  }

  web.window.visualViewport?.addEventListener(
      'resize',
      ((web.Event event) {
        updateKeyboardHeight();
      }).toJS);

  // Listen for window resize events to handle desktop browser window resizing
  web.window.addEventListener(
      'resize',
      ((web.Event event) {
        updateKeyboardHeight();
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
