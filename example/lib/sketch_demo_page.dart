import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

/// Live demo of the Excalidraw-style sketch layer as a self-contained
/// Miro-like whiteboard.
///
/// Run via the main app, or as a standalone entry:
///
/// ```
/// cd example
/// flutter run -t lib/sketch_demo_page.dart
/// ```
class SketchDemoPage extends StatefulWidget {
  const SketchDemoPage({
    super.key,
    this.isDark = false,
    this.onToggleTheme,
    this.controller,
  });

  final bool isDark;
  final VoidCallback? onToggleTheme;

  /// Optional externally-owned controller. When provided, the caller is
  /// responsible for disposing it — used to share the canvas state with
  /// the MCP control server (see `lib/control/`). Falls back to an
  /// internal controller when omitted.
  final SketchController? controller;

  @override
  State<SketchDemoPage> createState() => _SketchDemoPageState();
}

class _SketchDemoPageState extends State<SketchDemoPage> {
  late final SketchController _sketch;
  late final bool _ownsController;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _sketch = widget.controller ?? SketchController(currentTool: SketchTool.select);
  }

  @override
  void dispose() {
    if (_ownsController) _sketch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowCraft Whiteboard'),
      ),
      body: Row(
        children: [
          _buildToolPanel(scheme),
          Expanded(
            child: WhiteboardCanvas(
              sketchController: _sketch,
              backgroundColor: dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFFFFFFF),
              gridColor: dark
                  ? const Color(0x22FFFFFF)
                  : const Color(0x22888888),
              gridType: _showGrid ? GridType.dots : GridType.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel(ColorScheme scheme) {
    return Container(
      width: 112,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SketchToolbarRich(
                    controller: _sketch,
                    orientation: Axis.vertical,
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_4x4 : Icons.grid_off),
            tooltip: _showGrid ? 'Hide grid' : 'Show grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }
}

// ─── Standalone entry point ──────────────────────────────────────────────
// Run with: flutter run -t lib/sketch_demo_page.dart
void main() {
  runApp(const _StandaloneWhiteboardApp());
}

class _StandaloneWhiteboardApp extends StatefulWidget {
  const _StandaloneWhiteboardApp();

  @override
  State<_StandaloneWhiteboardApp> createState() =>
      _StandaloneWhiteboardAppState();
}

class _StandaloneWhiteboardAppState extends State<_StandaloneWhiteboardApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowCraft Whiteboard Demo',
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
