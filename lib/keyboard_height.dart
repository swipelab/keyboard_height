import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:keyboard_height/src/platform_interface/keyboard_height_platform_interface.dart';

class KeyboardHeight with ChangeNotifier {
  KeyboardHeight._() {
    _sub = KeyboardHeightPlatform.instance
        .keyboardHeightEventStream()
        .listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static final KeyboardHeight instance = KeyboardHeight._();
  StreamSubscription? _sub;

  double _height = 0.0;
  Duration _duration = Duration.zero;

  double get height => _height;
  Duration get duration => _duration;
  bool get isOpen => height > 0;

  void _onEvent(dynamic event) {
    final map = Map<String, dynamic>.from(event as Map);
    _height = (map['height'] as num).toDouble();
    _duration = Duration(milliseconds: (map['duration'] as num).toInt());
    notifyListeners();
  }
}
