import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'features/canvas/canvas_page_v2.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The board is a handwriting surface. Avoid the extra input resampling
  // stage so pointer samples can reach the live ink layer with less latency.
  GestureBinding.instance.resamplingEnabled = false;
  runApp(const InkBoardApp());
}

class InkBoardApp extends StatelessWidget {
  const InkBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '墨写',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111318),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const CanvasPageV2(),
    );
  }
}
