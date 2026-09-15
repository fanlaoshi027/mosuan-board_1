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

/// Low-latency ink surface.
/// Completed strokes are rasterized into a cached Picture. During a stroke,
/// only the live stroke is repainted; the completed page is simply replayed.
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
  final ValueNotifier<int> _liveRevision = ValueNotifier<int>(0);
  _InkStroke? _current;
  int? _activePointer;
  Picture? _cachedPicture;
  Size _cachedSize = Size.zero;

  @override
  void dispose() {
    _liveRevision.dispose();
    _cachedPicture?.dispose();
    super.dispose();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
    _rebuildCache(_cachedSize);
  }

  void redo() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
    _rebuildCache(_cachedSize);
  }

  void clear() {
    if (_strokes.isEmpty && _current == null) return;
    setState(() {
      _strokes.clear();
      _redo.clear();
      _current = null;
      _activePointer = null;
    });
    _cachedPicture?.dispose();
    _cachedPicture = null;
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
    final pressure = _normalize(event);

    // Ignore only truly redundant sub-pixel samples. Pressure changes are kept.
    if (points.isNotEmpty && (next - points.last.position).distance < 0.25 &&
        (pressure - points.last.pressure).abs() < 0.005) {
      _report(event);
      return;
    }

    points.add(_InkPoint(next, pressure));
    _liveRevision.value++;
    _report(event);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = _current;
    _current = null;
    _activePointer = null;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _rebuildCache(_cachedSize);
    }
    _liveRevision.value++;
    _report(event);
  }

  double _normalize(PointerEvent event) {
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0.0001) return event.pressure.clamp(0.0, 1.0);
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }

  void _rebuildCache(Size size) {
    if (size.isEmpty) return;
    _cachedPicture?.dispose();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final stroke in _strokes) {
      _paintStroke(canvas, stroke);
    }
    _cachedPicture = recorder.endRecording();
    _cachedSize = size;
    _liveRevision.value++;
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
          painter: _InkPainter(
            revision: _liveRevision,
            cachedPicture: _cachedPicture,
            current: _current,
            color: widget.color,
            width: widget.width,
            onSize: (size) {
              if (size != _cachedSize && !size.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildCache(size));
              }
            },
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  void _paintStroke(Canvas canvas, _InkStroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      final paint = _paintFor(points.first.pressure);
      canvas.drawCircle(points.first.position, paint.strokeWidth / 2, paint);
      return;
    }
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      canvas.drawLine(a.position, b.position, _paintFor((a.pressure + b.pressure) * 0.5));
    }
  }

  Paint _paintFor(double pressure) {
    final p = pressure.clamp(0.0, 1.0);
    return Paint()
      ..color = widget.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = (widget.width * (0.58 + p * 0.92)).clamp(0.8, widget.width * 1.5);
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({required this.revision, required this.cachedPicture, required this.current, required this.color, required this.width, required this.onSize}) : super(repaint: revision);
  final ValueNotifier<int> revision;
  final Picture? cachedPicture;
  final _InkStroke? current;
  final Color color;
  final double width;
  final ValueChanged<Size> onSize;

  @override
  void paint(Canvas canvas, Size size) {
    onSize(size);
    final picture = cachedPicture;
    if (picture != null) canvas.drawPicture(picture);
    if (current == null) return;
    final points = current!.points;
    if (points.length == 1) {
      final paint = _paintFor(points.first.pressure);
      canvas.drawCircle(points.first.position, paint.strokeWidth / 2, paint);
      return;
    }
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      canvas.drawLine(a.position, b.position, _paintFor((a.pressure + b.pressure) * 0.5));
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
      oldDelegate.cachedPicture != cachedPicture ||
      oldDelegate.current != current ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}
