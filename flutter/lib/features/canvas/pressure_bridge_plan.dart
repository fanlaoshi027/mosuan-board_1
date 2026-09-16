/// Pressure-only milestone.
///
/// The production implementation must obtain real hardware pressure from the
/// macOS native event layer and feed it into the ink stroke width calculation.
/// This file intentionally contains no UI or other features.
class PressureBridgePlan {
  static const String source = 'macOS native tablet/NSEvent pressure';
  static const String target = 'ink stroke width';
}
