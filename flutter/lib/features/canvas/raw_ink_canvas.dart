import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RawInkSample {
  const RawInkSample({required this.kind, required this.pressure, required this.pressureMin, required this.pressureMax, required this.timeStamp});
  final PointerDeviceKind kind;
  final double pressure;
  final double pressureMin;
  final double pressureMax;
  final Duration timeStamp;
}

class _InkPoint {
  const _InkPoint(this.position, this.pressure);
  final Offset position;
  final double pressure;
}

class _InkStroke {
  _InkStroke(this.points);
  final List<_InkPoint> points;
}

/// Direct live ink surface.
///
/// The live stroke intentionally uses StatefulWidget repainting rather than
/// relying on a repaint Listenable plus a RepaintBoundary. This keeps the
/// input-to-paint path explicit and, more importantly, guarantees that every
/// accepted pointer sample can invalidate the visible stroke immediately.
class RawInkCanvas extends StatefulWidget {
  const RawInkCanvas({super.key, required this.color, required this.width, this.onSample, this.backgroundColor = const Color(0xFFF9F9F7)});
  final Color color;
  final double width;
  final ValueChanged<RawInkSample>? onSample;
  final Color backgroundColor;

  @override
  State<RawInkCanvas> createState() => RawInkCanvasState();
}

class RawInkCanvasState extends State<RawInkCanvas> {
  final List<_InkStroke> _strokes = <_InkStroke>[];
  final List<_InkStroke> _redo = <_InkStroke>[];
  _InkStroke? _current;
  int? _activePointer;

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
  }

  void redo() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
  }

  void clear() {
    if (_strokes.isEmpty && _current == null) return;
    setState(() {
      _strokes.clear();
      _redo.clear();
      _current = null;
      _activePointer = null;
    });
  }

  bool _accepts(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus ||
      event.kind == PointerDeviceKind.mouse;

  void _report(PointerEvent event) {
    widget.onSample?.call(RawInkSample(
      kind: event.kind,
      pressure: event.pressure,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
      timeStamp: event.timeStamp,
    ));
  }

  void _down(PointerDownEvent event) {
    if (!_accepts(event)) return;
    _activePointer = event.pointer;
    _redo.clear();
    setState(() {
      _current = _InkStroke(<_InkPoint>[_InkPoint(event.localPosition, _normalize(event))]);
    });
    _report(event);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _current == null) return;
    final points = _current!.points;
    final next = event.localPosition;
    final pressure = _normalize(event);

    // Do not discard fast-input samples. The display can decide how much to
    // rasterize, but the input path must stay lossless for responsive ink.
    if (points.isNotEmpty && (next - points.last.position).distance < 0.25) {
      // Still retain pressure changes at the same coordinate so a force change
      // is visible instead of being silently flattened.
      if ((pressure - points.last.pressure).abs() < 0.005) {
        _report(event);
        return;
      }
    }

    points.add(_InkPoint(next, pressure));
    setState(() {});
    _report(event);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = _current;
    if (stroke != null && stroke.points.isNotEmpty) {
      setState(() {
        _strokes.add(stroke);
        _current = null;
        _activePointer = null;
      });
    } else {
      _activePointer = null;
    }
    _report(event);
  }

  double _normalize(PointerEvent event) {
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0.0001) return event.pressure.clamp(0.0, 1.0);
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _finish,
        onPointerCancel: _finish,
        child: CustomPaint(
          painter: _InkPainter(strokes: _strokes, current: _current, color: widget.color, width: widget.width),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter({required this.strokes, required this.current, required this.color, required this.width});
  final List<_InkStroke> strokes;
  final _InkStroke? current;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (current != null) _paintStroke(canvas, current!);
  }

  void _paintStroke(Canvas canvas, _InkStroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = points.first;
      final paint = _paintFor(p.pressure);
      canvas.drawCircle(p.position, paint.strokeWidth / 2, paint);
      return;
    }

    // Segment-by-segment rendering is intentionally simple here. It avoids
    // reconstructing pressure-band paths and makes every new segment visible
    // immediately. Once latency is proven, this can be replaced by a cached
    // raster path without changing the input model.
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final pressure = (a.pressure + b.pressure) * 0.5;
      canvas.drawLine(a.position, b.position, _paintFor(pressure));
    }
  }

  Paint _paintFor(double pressure) {
    final p = pressure.clamp(0.0, 1.0);
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = (width * (0.58 + p * 0.92)).clamp(0.8, width * 1.5);
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.current != current ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}
