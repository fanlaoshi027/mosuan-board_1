import 'package:flutter/material.dart';
import 'package:scribe_canvas/scribe_canvas.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final ScribeCanvasController _controller = ScribeCanvasController();

  bool _isEraser = false;
  bool _isPanMode = false;
  double _strokeWidth = 4;
  Color _color = Colors.white;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 76, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: const Color(0xFFF9F9F7),
                  child: ScribeCanvas(
                    controller: _controller,
                    color: _color,
                    strokeWidth: _strokeWidth,
                    isEraser: _isEraser,
                    isPanMode: _isPanMode,
                    multiPage: false,
                    onStrokeEnd: () => setState(() {}),
                    onUndo: () => setState(() {}),
                    onRedo: () => setState(() {}),
                  ),
                ),
              ),
            ),
          ),
          _buildTopBar(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '墨写',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            _toolButton(
              icon: Icons.edit_rounded,
              active: !_isEraser && !_isPanMode,
              onPressed: () => setState(() {
                _isEraser = false;
                _isPanMode = false;
              }),
              tooltip: '画笔',
            ),
            _toolButton(
              icon: Icons.auto_fix_normal_rounded,
              active: _isEraser,
              onPressed: () => setState(() {
                _isEraser = true;
                _isPanMode = false;
              }),
              tooltip: '橡皮',
            ),
            _toolButton(
              icon: Icons.pan_tool_alt_rounded,
              active: _isPanMode,
              onPressed: () => setState(() {
                _isPanMode = true;
                _isEraser = false;
              }),
              tooltip: '平移',
            ),
            const VerticalDivider(indent: 12, endIndent: 12),
            _colorButton(Colors.white),
            _colorButton(const Color(0xFFE53935)),
            _colorButton(const Color(0xFF1E88E5)),
            _colorButton(const Color(0xFFFFC107)),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _strokeWidth,
                dropdownColor: const Color(0xFF1A1D24),
                items: const [2.0, 4.0, 7.0, 10.0, 16.0]
                    .map((width) => DropdownMenuItem(
                          value: width,
                          child: Text('${width.toInt()} px'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _strokeWidth = value);
                },
              ),
            ),
            const Spacer(),
            _toolButton(
              icon: Icons.undo_rounded,
              onPressed: _controller.undo,
              tooltip: '撤销',
            ),
            _toolButton(
              icon: Icons.redo_rounded,
              onPressed: _controller.redo,
              tooltip: '重做',
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
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

  Widget _colorButton(Color color) {
    final selected = _color == color;
    return IconButton(
      tooltip: '颜色',
      onPressed: () => setState(() => _color = color),
      icon: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF4F8CFF) : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
