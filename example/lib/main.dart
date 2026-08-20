import 'package:flutter/material.dart';

import 'sketch_demo_page.dart';

void main() {
  runApp(const FlowCraftWhiteboardApp());
}

class FlowCraftWhiteboardApp extends StatefulWidget {
  const FlowCraftWhiteboardApp({super.key});

  @override
  State<FlowCraftWhiteboardApp> createState() => _FlowCraftWhiteboardAppState();
}

class _FlowCraftWhiteboardAppState extends State<FlowCraftWhiteboardApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowCraft Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: SketchDemoPage(
        isDark: _dark,
        onToggleTheme: () => setState(() => _dark = !_dark),
      ),
    );
  }
}
