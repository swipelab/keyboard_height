# keyboard_height

A Flutter plugin that provides the keyboard height and visibility for iOS, Android, and Web.

[![Pub Version](https://img.shields.io/pub/v/keyboard_height.svg)](https://pub.dev/packages/keyboard_height) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Package on pub.dev: https://pub.dev/packages/keyboard_height

## Features

- Provides the current keyboard height as a `ChangeNotifier`. on Web the keyboard height is reported as 0 when the viewport is scrolled by the browser.
- Works seamlessly across mobile (iOS, Android) and Web.
- A single, simple API for all platforms.

## Usage

The `KeyboardHeight` class is a `ChangeNotifier` singleton. You can listen to it to get real-time updates on the keyboard's height and visibility.

The API is the same for all platforms.

### Example

Here is a typical example showing how to use `AnimatedBuilder` to adjust your UI when the keyboard appears. This will smoothly animate a bottom container to match the keyboard's height.

```dart
import 'package:flutter/material.dart';
import 'package:keyboard_height/keyboard_height.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: KeyboardAwareScreen(),
    );
  }
}

class KeyboardAwareScreen extends StatelessWidget {
  const KeyboardAwareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: KeyboardHeight.instance,
      builder: (context, child) {
        final keyboardHeight = KeyboardHeight.instance.height;
        final keyboardDuration = KeyboardHeight.instance.duration;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Keyboard Height Example'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Tap me!',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Spacer(),
                Text(
                  'Keyboard is ${KeyboardHeight.instance.isOpen ? 'OPEN' : 'CLOSED'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Height: ${keyboardHeight.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // This container will animate its height to match the keyboard.
                AnimatedContainer(
                  duration: keyboardDuration,
                  curve: Curves.easeInOut,
                  height: keyboardHeight,
                  color: Colors.blue.withOpacity(0.5),
                  child: Center(
                    child: Text(
                      'This space is for the keyboard',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```