import 'dart:math' as math;
import 'package:flutter/gestures.dart';

/// Pressure-only input helper.
///
/// Keeps pressure handling deliberately small: no smoothing, prediction,
/// interpolation, or other drawing features are introduced here.
class PressureProbe {
  const PressureProbe();

  double read(PointerEvent event) {
    final min = event.pressureMin;
    final max = event.pressureMax;
    final raw = event.pressure;
    if (!raw.isFinite) return 0.5;
    if (max > min && max.isFinite && min.isFinite) {
      return ((raw - min) / (max - min)).clamp(0.0, 1.0);
    }
    return raw.clamp(0.0, 1.0);
  }

  /// Maps normalized pressure to a stable writing width.
  /// Kept intentionally conservative until hardware pressure is verified.
  double width({required double pressure, double minWidth = 1.5, double maxWidth = 6.0}) {
    final p = pressure.clamp(0.0, 1.0);
    final curved = math.pow(p, 0.72).toDouble();
    return minWidth + (maxWidth - minWidth) * curved;
  }
}
