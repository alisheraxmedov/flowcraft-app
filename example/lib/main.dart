import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

import 'home.dart';
import 'execution_test_page.dart';
import 'node_toolkit_page.dart';
import 'nodes/webhook_node.dart';
import 'nodes/openai_node.dart';

void main() {
  runApp(const FlowCraftExampleApp());
}

class FlowCraftExampleApp extends StatelessWidget {
  const FlowCraftExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowCraft',
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
      home: const CleanCanvasPage(),
    );
  }
}

/// Clean canvas — o'zingiz node larni qo'lda qo'shib ishlaysiz.
class CleanCanvasPage extends StatefulWidget {
  const CleanCanvasPage({super.key});

  @override
  State<CleanCanvasPage> createState() => _CleanCanvasPageState();
}

class _CleanCanvasPageState extends State<CleanCanvasPage> {
  late FlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlowController(snapToGrid: true, gridSnap: 20);
    _registerAll(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _registerAll(FlowController c) {
    c.nodeDefinitionRegistry
      ..register(TriggerNodeDef())
      ..register(TransformNodeDef())
      ..register(HttpRequestNodeDef())
      ..register(ConditionNodeDef())
      ..register(OutputNodeDef())
      ..register(MergeNodeDef())
      ..register(DelayNodeDef())
      ..register(LoopNodeDef())
      ..register(ErrorHandlerNodeDef())
      ..register(VariableNodeDef())
      ..register(WebhookNodeDef())
      ..register(OpenAiNodeDef())
      ..register(GeminiNodeDef())
      ..register(TelegramNodeDef());

    // Custom node widget builders (canvas rendering)
    c.nodeTypeRegistry.register('webhook', WebhookNode.builder);
    c.nodeTypeRegistry.register('openai', OpenAINode.builder);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowCraft'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Old Home Page',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HomePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.science_rounded),
            tooltip: 'Execution Test',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ExecutionTestPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize_rounded),
            tooltip: 'Node Toolkit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const NodeToolkitPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: FlowCanvas(
              controller: _controller,
              theme: isDark ? FlowTheme.dark() : FlowTheme.light(),
              enableKeyboardShortcuts: true,
              showControls: true,
              overlays: [
                Positioned(
                  top: 12,
                  left: 12,
                  child: InkWell(
                    onTap: () {
                      final count = _controller.nodes.length;
                      _controller.addNode(
                        type: NodeType.trigger,
                        label: 'Webhook',
                        position: Offset(100 + count * 50, 100 + count * 50),
                        size: const Size(100, 100),
                        data: const {
                          'direction': 'input',
                          'definitionType': 'webhook',
                          'method': 'POST',
                          'path': '/api/incoming',
                          'testPayload': {'event': 'test'},
                        },
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: const Icon(Icons.webhook, color: Colors.deepOrange, size: 28),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 74,
                  child: InkWell(
                    onTap: () {
                      final count = _controller.nodes.length;
                      _controller.addNode(
                        type: NodeType.defaultNode,
                        label: 'OpenAI',
                        position: Offset(200 + count * 50, 100 + count * 50),
                        size: const Size(100, 100),
                        data: const {
                          'definitionType': 'openai',
                        },
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey, width: 2),
                      ),
                      child: const Icon(Icons.chat, color: Colors.grey, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          NodePropertiesPanel(controller: _controller),
        ],
      ),
    );
  }
}
