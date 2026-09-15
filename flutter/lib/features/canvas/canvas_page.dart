import 'package:fluera_canvas/fluera_canvas.dart';
import 'package:flutter/material.dart';

class _PenPreset {
  const _PenPreset({
    required this.name,
    required this.color,
    required this.width,
    required this.icon,
  });

  final String name;
  final Color color;
  final double width;
  final IconData icon;
}

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasKey = GlobalKey<FlueraCanvasState>();

  static const _presets = <_PenPreset>[
    _PenPreset(
      name: '黑色钢笔',
      color: Color(0xFF202124),
      width: 3.0,
      icon: Icons.edit_rounded,
    ),
    _PenPreset(
      name: '红色钢笔',
      color: Color(0xFFE53935),
      width: 3.5,
      icon: Icons.edit_rounded,
    ),
    _PenPreset(
      name: '蓝色钢笔',
      color: Color(0xFF1E88E5),
      width: 3.5,
      icon: Icons.edit_rounded,
    ),
    _PenPreset(
      name: '绿色钢笔',
      color: Color(0xFF43A047),
      width: 3.5,
      icon: Icons.edit_rounded,
    ),
    _PenPreset(
      name: '黄色荧光笔',
      color: Color(0xFFFFC107),
      width: 10.0,
      icon: Icons.brush_rounded,
    ),
  ];

  CanvasTool _tool = CanvasTool.draw;
  Color _color = const Color(0xFF202124);
  double _width = 3.0;
  double _eraserRadius = 22.0;
  int _selectedPreset = 0;
  bool _dockOnLeft = false;

  void _selectPen(Color color, double width, {int? presetIndex}) {
    setState(() {
      _tool = CanvasTool.draw;
      _color = color;
      _width = width;
      if (presetIndex != null) _selectedPreset = presetIndex;
    });
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
                child: FlueraCanvas(
                  key: _canvasKey,
                  tool: _tool,
                  strokeColor: _color,
                  strokeWidth: _width,
                  eraserRadius: _eraserRadius,
                  showEraserPreview: true,
                  enableKeyboardShortcuts: true,
                  background: const CanvasBackground.solid(Color(0xFFF9F9F7)),
                ),
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
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 7),
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            const Text(
              '墨写',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 18),
            _toolButton(
              icon: Icons.edit_rounded,
              label: '画笔',
              active: _tool == CanvasTool.draw,
              onPressed: () => _selectPen(_color, _width),
            ),
            _toolButton(
              icon: Icons.auto_fix_normal_rounded,
              label: '橡皮',
              active: _tool == CanvasTool.erase,
              onPressed: () => setState(() => _tool = CanvasTool.erase),
            ),
            _toolButton(
              icon: Icons.ads_click_rounded,
              label: '选择',
              active: _tool == CanvasTool.select,
              onPressed: () => setState(() => _tool = CanvasTool.select),
            ),
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
              icon: Icons.gesture_rounded,
              text: '压感就绪',
              active: _tool == CanvasTool.draw,
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: _dockOnLeft ? '笔槽移到右侧' : '笔槽移到左侧',
              onPressed: () => setState(() => _dockOnLeft = !_dockOnLeft),
              icon: Icon(
                _dockOnLeft ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
                size: 20,
              ),
            ),
            IconButton(
              tooltip: '撤销',
              onPressed: () => _canvasKey.currentState?.undo(),
              icon: const Icon(Icons.undo_rounded, size: 21),
            ),
            IconButton(
              tooltip: '重做',
              onPressed: () => _canvasKey.currentState?.redo(),
              icon: const Icon(Icons.redo_rounded, size: 21),
            ),
            IconButton(
              tooltip: '清空',
              onPressed: () => _canvasKey.currentState?.clear(),
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPenDock() {
    return Positioned(
      left: _dockOnLeft ? 24 : null,
      right: _dockOnLeft ? null : 24,
      top: 94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24).withValues(alpha: .96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 8),
              color: Colors.black26,
            ),
          ],
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(Icons.push_pin_rounded, size: 16, color: Colors.white54),
            ),
            for (var i = 0; i < _presets.length; i++) ...[
              _presetButton(_presets[i], i),
              if (i != _presets.length - 1) const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presetButton(_PenPreset preset, int index) {
    final selected = _selectedPreset == index && _tool == CanvasTool.draw;
    return Tooltip(
      message: preset.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _selectPen(preset.color, preset.width, presetIndex: index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF315FBE)
                : Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(preset.icon, size: 18, color: preset.color),
              Positioned(
                bottom: 6,
                child: Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: preset.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              active ? const Color(0xFF315FBE) : Colors.transparent,
          foregroundColor: active ? Colors.white : Colors.white70,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _color.toARGB32() == color.toARGB32() && _tool == CanvasTool.draw;
    return IconButton(
      tooltip: '颜色',
      onPressed: () => _selectPen(color, _width),
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
        onTap: () => _selectPen(_color, width),
        child: Container(
          width: 30,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF315FBE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: width.clamp(2, 12),
            height: width.clamp(2, 12),
            decoration: const BoxDecoration(
              color: Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String text,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF1D6B49).withValues(alpha: .75)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? const Color(0xFF8FF0BF) : Colors.white38),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
