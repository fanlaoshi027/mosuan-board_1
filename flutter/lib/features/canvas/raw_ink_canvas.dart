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

/// Minimal low-latency ink surface.
///
/// Live input deliberately keeps the geometry cheap: very close samples are
/// coalesced, while pressure is still rendered in small pressure bands.
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
  final ValueNotifier<int> _historyRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _liveRevision = ValueNotifier<int>(0);
  final List<_InkStroke> _strokes = <_InkStroke>[];
  final List<_InkStroke> _redo = <_InkStroke>[];
  _InkStroke? _current;
  int? _activePointer;

  @override
  void dispose() {
    _historyRevision.dispose();
    _liveRevision.dispose();
    super.dispose();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    _historyRevision.value++;
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    _historyRevision.value++;
  }

  void clear() {
    if (_strokes.isEmpty && _current == null) return;
    _strokes.clear();
    _redo.clear();
    _current = null;
    _historyRevision.value++;
    _liveRevision.value++;
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
    _current = _InkStroke(<_InkPoint>[_InkPoint(event.localPosition, _normalize(event))]);
    _liveRevision.value++;
    _report(event);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _current == null) return;
    final points = _current!.points;
    final next = event.localPosition;
    // Do not flood the live painter with sub-pixel samples. Keep every sample
    // for the diagnostic stream, but only store geometry that moves the stroke.
    if (points.isNotEmpty && (next - points.last.position).distance < 0.7) {
      _report(event);
      return;
    }
    points.add(_InkPoint(next, _normalize(event)));
    _liveRevision.value++;
    _report(event);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = _current;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _historyRevision.value++;
    }
    _current = null;
    _activePointer = null;
    _liveRevision.value++;
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
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                painter: _HistoryInkPainter(revision: _historyRevision, strokes: _strokes, color: widget.color, width: widget.width),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _LiveInkPainter(revision: _liveRevision, stroke: _current, color: widget.color, width: widget.width),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInkPainter extends CustomPainter {
  _HistoryInkPainter({required this.revision, required this.strokes, required this.color, required this.width}) : super(repaint: revision);
  final ValueNotifier<int> revision;
  final List<_InkStroke> strokes;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
  }

  void _paintStroke(Canvas canvas, _InkStroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = points.first;
      canvas.drawCircle(p.position, _paintFor(p.pressure).strokeWidth / 2, _paintFor(p.pressure));
      return;
    }

    if (_pressureVaries(points)) {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        canvas.drawLine(a.position, b.position, _paintFor((a.pressure + b.pressure) / 2));
      }
      return;
    }

    final path = Path()..moveTo(points.first.position.dx, points.first.position.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].position.dx, points[i].position.dy);
    }
    canvas.drawPath(path, _paintFor(points.first.pressure));
  }

  bool _pressureVaries(List<_InkPoint> points) {
    final first = points.first.pressure;
    for (var i = 1; i < points.length; i++) {
      if ((points[i].pressure - first).abs() > 0.01) return true;
    }
    return false;
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
  bool shouldRepaint(covariant _HistoryInkPainter oldDelegate) => oldDelegate.color != color || oldDelegate.width != width;
}

class _LiveInkPainter extends CustomPainter {
  _LiveInkPainter({required this.revision, required this.stroke, required this.color, required this.width}) : super(repaint: revision);
  final ValueNotifier<int> revision;
  final _InkStroke? stroke;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final points = stroke?.points;
    if (points == null || points.isEmpty) return;
    if (points.length == 1) {
      final paint = _paintFor(points.first.pressure);
      canvas.drawCircle(points.first.position, paint.strokeWidth / 2, paint);
      return;
    }

    // Keep the live path cheap, but do not freeze its width at the first
    // pressure value. Consecutive points are grouped into coarse pressure
    // bands, so pressure changes require only a handful of drawPath calls.
    final paths = <int, Path>{};
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final band = (((a.pressure + b.pressure) * 0.5) * 7).round().clamp(0, 7);
      final path = paths.putIfAbsent(band, () => Path()..moveTo(a.position.dx, a.position.dy));
      path.lineTo(b.position.dx, b.position.dy);
    }
    for (final entry in paths.entries) {
      final pressure = (entry.key / 7.0).clamp(0.0, 1.0);
      canvas.drawPath(entry.value, _paintFor(pressure));
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
  bool shouldRepaint(covariant _LiveInkPainter oldDelegate) => oldDelegate.color != color || oldDelegate.width != width;
}
