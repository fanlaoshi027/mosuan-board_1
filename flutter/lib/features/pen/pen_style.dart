import 'package:flutter/material.dart';

enum PenKind { ballpoint, fountain, highlighter }

/// A deliberately small pen model for the teaching-board MVP.
///
/// The canvas engine remains responsible for pressure-aware input. These
/// values describe the teaching-oriented presets that we expose in the UI.
class PenStyle {
  const PenStyle({
    required this.name,
    required this.kind,
    required this.color,
    required this.width,
    this.opacity = 1.0,
  });

  final String name;
  final PenKind kind;
  final Color color;
  final double width;
  final double opacity;

  static const ballpointBlack = PenStyle(
    name: '圆珠笔',
    kind: PenKind.ballpoint,
    color: Color(0xFF202124),
    width: 3.0,
  );

  static const fountainRed = PenStyle(
    name: '钢笔·红',
    kind: PenKind.fountain,
    color: Color(0xFFE53935),
    width: 3.5,
  );

  static const fountainBlue = PenStyle(
    name: '钢笔·蓝',
    kind: PenKind.fountain,
    color: Color(0xFF1E88E5),
    width: 3.5,
  );

  static const highlighter = PenStyle(
    name: '荧光笔',
    kind: PenKind.highlighter,
    color: Color(0xFFFFB300),
    width: 10.0,
    opacity: 0.42,
  );

  static const favorites = <PenStyle>[
    ballpointBlack,
    fountainRed,
    fountainBlue,
    highlighter,
  ];
}
