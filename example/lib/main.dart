import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

import 'control/app_control.dart';
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
  bool _mcpEnabled = true;

  late final SketchController _sketch =
      SketchController(currentTool: SketchTool.select);
  late final AppControlServer _controlServer =
      AppControlServer(controller: _sketch);

  @override
  void initState() {
    super.initState();
    _controlServer.start().catchError((Object e) {
      debugPrint('FlowCraft control server failed to start: $e');
    });
  }

  void _toggleMcp() {
    final enabling = !_mcpEnabled;
    setState(() => _mcpEnabled = enabling);
    final future = enabling ? _controlServer.start() : _controlServer.stop();
    future.catchError((Object e) {
      debugPrint(
        'FlowCraft control server ${enabling ? 'start' : 'stop'} failed: $e',
      );
    });
  }

  @override
  void dispose() {
    _controlServer.stop();
    _sketch.dispose();
    super.dispose();
  }

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
        controller: _sketch,
        isDark: _dark,
        onToggleTheme: () => setState(() => _dark = !_dark),
        mcpEnabled: _mcpEnabled,
        onToggleMcp: _toggleMcp,
      ),
    );
  }
}
