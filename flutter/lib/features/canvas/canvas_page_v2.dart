import 'dart:async';

import 'package:fluera_canvas/fluera_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../pen/pen_editor_dialog.dart';
import '../pen/pen_style.dart';
import 'raw_ink_canvas.dart';

class CanvasPageV2 extends StatefulWidget {
  const CanvasPageV2({super.key});

  @override
  State<CanvasPageV2> createState() => _CanvasPageV2State();
}

enum _DockSide { left, right }

class _CanvasPageV2State extends State<CanvasPageV2> {
  final _flueraKey = GlobalKey<FlueraCanvasState>();
  final _rawKey = GlobalKey<RawInkCanvasState>();

  CanvasTool _tool = CanvasTool.draw;
  PenStyle _pen = PenStyle.ballpointBlack;
  double _width = PenStyle.ballpointBlack.width;
  final double _eraserRadius = 22.0;
  int _selectedPreset = 0;
  _DockSide _dockSide = _DockSide.right;
  late List<PenStyle> _favorites;

  PointerDeviceKind? _inputKind;
  double _pressure = 0.0;
  double _pressureMin = 0.0;
  double _pressureMax = 1.0;
  int _sampleCount = 0;
  int _samplesPerSecond = 0;
  Timer? _sampleTimer;

  @override
  void initState() {
    super.initState();
    _favorites = List<PenStyle>.from(PenStyle.favorites);
    _sampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _samplesPerSecond = _sampleCount;
        _sampleCount = 0;
      });
    });
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }

  void _observeSample(RawInkSample sample) {
    _sampleCount++;
    _inputKind = sample.kind;
    _pressure = sample.pressure;
    _pressureMin = sample.pressureMin;
    _pressureMax = sample.pressureMax;
  }

  void _selectPen(PenStyle pen, {double? width, int? presetIndex}) {
    setState(() {
      _tool = CanvasTool.draw;
      _pen = pen;
      _width = width ?? pen.width;
      if (presetIndex != null) _selectedPreset = presetIndex;
    });
  }

  void _selectColor(Color color) {
    _selectPen(
      PenStyle(
        name: _pen.name,
        kind: _pen.kind,
        color: color,
        width: _width,
        opacity: _pen.opacity,
      ),
    );
  }

  Future<void> _editFavorite(int index) async {
    final edited = await showDialog<PenStyle>(
      context: context,
      builder: (_) => PenEditorDialog(initial: _favorites[index]),
    );
    if (!mounted || edited == null) return;
    setState(() {
      _favorites[index] = edited;
      if (_selectedPreset == index) {
        _pen = edited;
        _width = edited.width;
      }
    });
  }

  Widget _buildCanvas() {
    if (_tool == CanvasTool.draw) {
      return RawInkCanvas(
        key: _rawKey,
        color: _pen.color.withValues(alpha: _pen.opacity),
        width: _width,
        onSample: _observeSample,
      );
    }

    return FlueraCanvas(
      key: _flueraKey,
      tool: _tool,
      strokeColor: _pen.color.withValues(alpha: _pen.opacity),
      strokeWidth: _width,
      eraserRadius: _eraserRadius,
      showEraserPreview: true,
      enableKeyboardShortcuts: true,
      background: const CanvasBackground.solid(Color(0xFFF9F9F7)),
    );
  }

  void _undo() {
    if (_tool == CanvasTool.draw) {
      _rawKey.currentState?.undo();
    } else {
      _flueraKey.currentState?.undo();
    }
  }

  void _redo() {
    if (_tool == CanvasTool.draw) {
      _rawKey.currentState?.redo();
    } else {
      _flueraKey.currentState?.redo();
    }
  }

  void _clear() {
    if (_tool == CanvasTool.draw) {
      _rawKey.currentState?.clear();
    } else {
      _flueraKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 74, 14, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildCanvas(),
              ),
            ),
          ),
          _buildTopBar(),
          _buildPenDock(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final kind = _inputKind == null
        ? '未检测'
        : _inputKind.toString().split('.').last;
    final pressureText = _pressure.toStringAsFixed(2);
    final rangeText = '${_pressureMin.toStringAsFixed(2)}~${_pressureMax.toStringAsFixed(2)}';
    final inputText = '$kind  压力 $pressureText  [$rangeText] · $_samplesPerSecond Hz';

    return Positioned(
      top: 12,
      left: 14,
      right: 14,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: const [
            BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Colors.black26),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            const Text('墨写', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(width: 18),
            _toolButton(Icons.edit_rounded, '画笔', _tool == CanvasTool.draw, () => _selectPen(_pen, width: _width)),
            _toolButton(Icons.straighten_rounded, '直线', _tool == CanvasTool.line, () => setState(() => _tool = CanvasTool.line)),
            _toolButton(Icons.auto_fix_normal_rounded, '橡皮', _tool == CanvasTool.erase, () => setState(() => _tool = CanvasTool.erase)),
            _toolButton(Icons.auto_fix_high_rounded, '精细橡皮', _tool == CanvasTool.erasePixel, () => setState(() => _tool = CanvasTool.erasePixel)),
            const VerticalDivider(indent: 12, endIndent: 12, width: 18),
            _toolButton(Icons.ads_click_rounded, '选择', _tool == CanvasTool.select, () => setState(() => _tool = CanvasTool.select)),
            _toolButton(Icons.gesture_rounded, '套索', _tool == CanvasTool.lasso, () => setState(() => _tool = CanvasTool.lasso)),
            const VerticalDivider(indent: 12, endIndent: 12, width: 18),
            _colorDot(const Color(0xFF202124)),
            _colorDot(const Color(0xFFE53935)),
            _colorDot(const Color(0xFF1E88E5)),
            _colorDot(const Color(0xFF43A047)),
            _colorDot(const Color(0xFFFFB300)),
            const SizedBox(width: 8),
            _widthButton(2),
            _widthButton(4),
            _widthButton(7),
            _widthButton(10),
            const Spacer(),
            _statusChip(
              icon: Icons.speed_rounded,
              text: inputText,
              active: _inputKind == PointerDeviceKind.stylus || _inputKind == PointerDeviceKind.invertedStylus,
            ),
            const SizedBox(width: 8),
            IconButton(tooltip: '撤销', onPressed: _undo, icon: const Icon(Icons.undo_rounded, size: 21)),
            IconButton(tooltip: '重做', onPressed: _redo, icon: const Icon(Icons.redo_rounded, size: 21)),
            IconButton(tooltip: '清空', onPressed: _clear, icon: const Icon(Icons.delete_outline_rounded, size: 21)),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPenDock() {
    final isLeft = _dockSide == _DockSide.left;
    return Positioned(
      left: isLeft ? 24 : null,
      right: isLeft ? null : 24,
      top: 94,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24).withValues(alpha: .96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          children: [
            Tooltip(
              message: isLeft ? '移到右侧' : '移到左侧',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _dockSide = isLeft ? _DockSide.right : _DockSide.left),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Icon(Icons.push_pin_rounded, size: 16, color: Colors.white54),
                ),
              ),
            ),
            for (var i = 0; i < _favorites.length; i++) ...[
              _presetButton(_favorites[i], i),
              if (i != _favorites.length - 1) const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presetButton(PenStyle preset, int index) {
    final selected = _selectedPreset == index && _tool == CanvasTool.draw;
    return Tooltip(
      message: '${preset.name}（长按编辑）',
      child: GestureDetector(
        onLongPress: () => _editFavorite(index),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _selectPen(preset, presetIndex: index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF315FBE) : Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Container(
                width: preset.kind == PenKind.highlighter ? 27 : 23,
                height: preset.kind == PenKind.highlighter ? 12 : 23,
                decoration: BoxDecoration(
                  color: preset.color.withValues(alpha: preset.opacity),
                  shape: preset.kind == PenKind.highlighter ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: preset.kind == PenKind.highlighter ? BorderRadius.circular(6) : null,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, bool active, VoidCallback onPressed) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: active ? const Color(0xFF315FBE) : Colors.transparent,
          foregroundColor: active ? Colors.white : Colors.white70,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _pen.color == color && _tool == CanvasTool.draw;
    return IconButton(
      tooltip: '颜色',
      onPressed: () => _selectColor(color),
      icon: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF4F8CFF) : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  Widget _widthButton(double width) {
    final selected = _width == width && _tool == CanvasTool.draw;
    return Tooltip(
      message: '${width.toInt()} px',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectPen(_pen, width: width),
        child: Container(
          width: 30,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF315FBE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: width,
            height: width,
            decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _statusChip({required IconData icon, required String text, required bool active}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1D6B49).withValues(alpha: .75) : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? const Color(0xFF8FF0BF) : Colors.white38),
          const SizedBox(width: 5),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
