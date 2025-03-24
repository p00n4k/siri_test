import 'package:flutter/services.dart';

class SiriShortcut {
  static const MethodChannel _channel = MethodChannel('siri_shortcut');

  static Future<void> invokePM25Intent() async {
    await _channel.invokeMethod('invokePM25Intent');
  }
}
