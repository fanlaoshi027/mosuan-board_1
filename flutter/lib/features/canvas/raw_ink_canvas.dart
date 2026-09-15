import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RawInkSample {
  const RawInkSample({
    required this.kind,
    required this.pressure,
    required this.pressureMin,
    required this.pressureMax,
    required this.timeStamp,
  });

  final PointerDeviceKind kind;
  final double pressure;
  final double pressureMin;
  final double pressureMax;
  final Duration timeStamp;

  double get normalizedPressure {
    final range = pressureMax - pressureMin;
    if (range <= 0.0001) return pressure.clamp(0.0, 1.0);
    return ((pressure - pressureMin) / range).clamp(0.0, 1.0);
  }
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

/// A deliberately small raw-pointer ink surface.
///
/// It bypasses high-level gesture recognizers and third-party stroke
/// smoothing so the live stroke can follow Flutter's PointerMoveEvent as
/// closely as possible. Rendering densifies large sample gaps without adding
/// input latency or changing the stored geometry.
class RawInkCanvas extends StatefulWidget {
  const RawInkCanvas({
    super.key,
    required this.color,
    required this.width,
    this.onSample,
    this.backgroundColor = const Color(0xFFF9F9F7),
  });

  final Color color;
  final double width;
  final ValueChanged<RawInkSample>? onSample;
  final Color backgroundColor;

  @override
  State<RawInkCanvas> createState() => RawInkCanvasState();
}

class RawInkCanvasState extends State<RawInkCanvas> {
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  final List<_InkStroke> _strokes = <_InkStroke>[];
  final List<_InkStroke> _redo = <_InkStroke>[];
  _InkStroke? _current;
  int? _activePointer;

  @override
  void dispose() {
    _revision.dispose();
    super.dispose();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    _revision.value++;
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    _revision.value++;
  }

  void clear() {
    if (_strokes.isEmpty && _current == null) return;
    _strokes.clear();
    _redo.clear();
    _current = null;
    _revision.value++;
  }

  bool _accepts(PointerEvent event) {
    return event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
  }

  void _report(PointerEvent event) {
    widget.onSample?.call(
      RawInkSample(
        kind: event.kind,
        pressure: event.pressure,
        pressureMin: event.pressureMin,
        pressureMax: event.pressureMax,
        timeStamp: event.timeStamp,
      ),
    );
  }

  void _down(PointerDownEvent event) {
    if (!_accepts(event)) return;
    _activePointer = event.pointer;
    _redo.clear();
    _current = _InkStroke(<_InkPoint>[
      _InkPoint(event.localPosition, _normalize(event)),
    ]);
    _revision.value++;
    _report(event);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _current == null) return;
    _current!.points.add(_InkPoint(event.localPosition, _normalize(event)));
    _revision.value++;
    _report(event);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = _current;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
    }
    _current = null;
    _activePointer = null;
    _revision.value++;
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
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RawInkPainter(
              revision: _revision,
              strokes: _strokes,
              current: _current,
              color: widget.color,
              width: widget.width,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _RawInkPainter extends CustomPainter {
  _RawInkPainter({
    required this.revision,
    required this.strokes,
    required this.current,
    required this.color,
    required this.width,
  }) : super(repaint: revision);

  final ValueNotifier<int> revision;
  final List<_InkStroke> strokes;
  final _InkStroke? current;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (current != null) {
      _paintStroke(canvas, current!);
    }
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

    for (var i = 1; i < points.length; i++) {
      _drawDenseSegment(canvas, points[i - 1], points[i]);
    }

    final first = points.first;
    final last = points.last;
    final firstPaint = _paintFor(first.pressure);
    final lastPaint = _paintFor(last.pressure);
    canvas.drawCircle(first.position, firstPaint.strokeWidth / 2, firstPaint);
    canvas.drawCircle(last.position, lastPaint.strokeWidth / 2, lastPaint);
  }

  void _drawDenseSegment(Canvas canvas, _InkPoint a, _InkPoint b) {
    final dx = b.position.dx - a.position.dx;
    final dy = b.position.dy - a.position.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    // Fill large gaps with short linear segments. This only affects painting;
    // the original pointer samples remain untouched for diagnostics/history.
    final steps = math.max(1, (distance / 2.0).ceil());

    var previous = a.position;
    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final position = Offset(
        a.position.dx + dx * t,
        a.position.dy + dy * t,
      );
      final pressure = a.pressure + (b.pressure - a.pressure) * t;
      canvas.drawLine(previous, position, _paintFor(pressure));
      previous = position;
    }
  }

  Paint _paintFor(double pressure) {
    final p = pressure.clamp(0.0, 1.0);
    final factor = 0.58 + p * 0.92;
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = (width * factor).clamp(0.8, width * 1.5);
  }

  @override
  bool shouldRepaint(covariant _RawInkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.width != width;
  }
}
