import 'package:flutter/material.dart';
import 'features/canvas/canvas_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const CanvasPage(),
    );
  }
}
