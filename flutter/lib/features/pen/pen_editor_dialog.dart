import 'package:flutter/material.dart';

import 'pen_style.dart';

class PenEditorDialog extends StatefulWidget {
  const PenEditorDialog({super.key, required this.initial});

  final PenStyle initial;

  @override
  State<PenEditorDialog> createState() => _PenEditorDialogState();
}

class _PenEditorDialogState extends State<PenEditorDialog> {
  late PenKind _kind;
  late Color _color;
  late double _width;
  late double _opacity;

  static const _colors = <Color>[
    Color(0xFF202124),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFFB300),
    Color(0xFF8E24AA),
  ];

  @override
  void initState() {
    super.initState();
    _kind = widget.initial.kind;
    _color = widget.initial.color;
    _width = widget.initial.width;
    _opacity = widget.initial.opacity;
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighter = _kind == PenKind.highlighter;
    return AlertDialog(
      title: const Text('编辑收藏笔'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('笔型', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<PenKind>(
              segments: const [
                ButtonSegment(value: PenKind.ballpoint, label: Text('圆珠笔')),
                ButtonSegment(value: PenKind.fountain, label: Text('钢笔')),
                ButtonSegment(value: PenKind.highlighter, label: Text('荧光笔')),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() {
                _kind = value.first;
                if (_kind == PenKind.highlighter && _width < 8) _width = 10;
                if (_kind != PenKind.highlighter && _width > 8) _width = 4;
              }),
            ),
            const SizedBox(height: 20),
            const Text('颜色', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color ? Theme.of(context).colorScheme.primary : Colors.black12,
                          width: _color == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('粗细  ${_width.toStringAsFixed(1)} px', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              min: isHighlighter ? 6 : 1,
              max: isHighlighter ? 24 : 12,
              divisions: isHighlighter ? 18 : 22,
              value: _width.clamp(isHighlighter ? 6.0 : 1.0, isHighlighter ? 24.0 : 12.0),
              onChanged: (value) => setState(() => _width = value),
            ),
            if (isHighlighter) ...[
              Text('透明度  ${(_opacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                min: .15,
                max: .75,
                divisions: 12,
                value: _opacity,
                onChanged: (value) => setState(() => _opacity = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, _buildStyle()), child: const Text('保存')),
      ],
    );
  }

  PenStyle _buildStyle() {
    final name = switch (_kind) {
      PenKind.ballpoint => '圆珠笔',
      PenKind.fountain => '钢笔',
      PenKind.highlighter => '荧光笔',
    };
    return PenStyle(
      name: name,
      kind: _kind,
      color: _color,
      width: _width,
      opacity: _kind == PenKind.highlighter ? _opacity : 1.0,
    );
  }
}
