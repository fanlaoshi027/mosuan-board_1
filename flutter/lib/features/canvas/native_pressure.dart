import 'dart:async';

import 'package:flutter/services.dart';

/// macOS native pressure feed.
///
/// The Flutter pointer pipeline can expose a constant pressure value for some
/// tablet drivers. This feed receives the raw normalized pressure from AppKit
/// and makes the most recent value available to the ink surface.
class NativePressureFeed {
  NativePressureFeed._();

  static const EventChannel _channel = EventChannel('mosuan/native_pressure');
  static StreamSubscription<dynamic>? _subscription;
  static double _latest = 0.0;
  static int _lastMicros = 0;
  static bool _started = false;

  static double get latest => _latest;
  static bool get hasRecentValue =>
      _started &&
      _lastMicros > 0 &&
      DateTime.now().microsecondsSinceEpoch - _lastMicros < 120000;

  static void ensureStarted() {
    if (_started) return;
    _started = true;
    try {
      _subscription = _channel.receiveBroadcastStream().listen((dynamic value) {
        if (value is Map) {
          final raw = value['pressure'];
          final pressure = raw is num ? raw.toDouble() : null;
          if (pressure != null) {
            _latest = pressure.clamp(0.0, 1.0);
            _lastMicros = DateTime.now().microsecondsSinceEpoch;
          }
        }
      }, onError: (_) {
        // Non-macOS builds simply keep using Flutter's PointerEvent pressure.
      });
    } on MissingPluginException {
      // Expected on platforms where the native bridge is not present.
    } catch (_) {
      // Keep the drawing surface usable even if the bridge is unavailable.
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
