import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

/// Live demo of the Excalidraw-style sketch layer composed on top of the
/// FlowCraft canvas.
///
/// Run via the brush icon in the main app, or as a standalone entry:
///
/// ```
/// cd example
/// flutter run -t lib/sketch_demo_page.dart
/// ```
class SketchDemoPage extends StatefulWidget {
  const SketchDemoPage({super.key});

  @override
  State<SketchDemoPage> createState() => _SketchDemoPageState();
}

class _SketchDemoPageState extends State<SketchDemoPage> {
  late final FlowController _flow;
  late final SketchController _sketch;

  @override
  void initState() {
    super.initState();
    _flow = FlowController();
    _sketch = SketchController(currentTool: SketchTool.freedraw);

    // Seed a couple of demo nodes so users see sketches coexisting with
    // a flow graph.
    _flow.addNode(
      label: 'Trigger',
      type: NodeType.trigger,
      position: const Offset(80, 80),
      size: const Size(140, 70),
    );
    _flow.addNode(
      label: 'Process',
      position: const Offset(360, 120),
    );
  }

  @override
  void dispose() {
    _sketch.dispose();
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sketch + Flow demo'),
      ),
      body: Stack(
        children: [
          FlowCanvas(
            controller: _flow,
            sketchController: _sketch,
            showControls: true,
            theme: Theme.of(context).brightness == Brightness.dark
                ? FlowTheme.dark()
                : FlowTheme.light(),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Center(
              child: SketchToolbarRich(controller: _sketch),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Standalone entry point ──────────────────────────────────────────────
// Run with: flutter run -t lib/sketch_demo_page.dart
void main() {
  runApp(MaterialApp(
    title: 'FlowCraft Sketch Demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: const SketchDemoPage(),
  ));
}
