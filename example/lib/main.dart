import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

import 'home.dart';
import 'execution_test_page.dart';
import 'node_toolkit_page.dart';
import 'nodes/webhook_node.dart';
import 'nodes/openai_node.dart';
import 'nodes/telegram_node.dart';
import 'nodes/gemini_node.dart';
import 'storage/flow_storage.dart';
import 'package:flowcraft/overlays/expandable_bottom_sheet.dart';

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
  late WorkflowServer _server;
  bool _isServerRunning = false;

  @override
  void initState() {
    super.initState();
    _controller = FlowController(snapToGrid: true, gridSnap: 20);
    _registerAll(_controller);
    
    _server = WorkflowServer(controller: _controller);
    _server.events.listen((event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.type.name}: ${event.message}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _server.dispose();
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
    c.nodeTypeRegistry.register('gemini', GeminiNode.builder);
    c.nodeTypeRegistry.register('telegram', TelegramNode.builder);
  }

  void _showSaveDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Flow'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Flow name',
            hintText: 'Enter a name for this flow',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final json = _controller.toJson();
              await FlowStorage.instance.saveFlow(
                name: name,
                jsonData: json,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Flow "$name" saved!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog(BuildContext context) async {
    final flows = await FlowStorage.instance.listFlows();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Flow'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: flows.isEmpty
              ? const Center(child: Text('No saved flows yet'))
              : ListView.separated(
                  itemCount: flows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final flow = flows[index];
                    final name = flow['name'] as String;
                    final updatedAt = flow['updated_at'] as String;
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        updatedAt.substring(0, 16).replaceFirst('T', ' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await FlowStorage.instance
                              .deleteFlow(flow['id'] as int);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) _showLoadDialog(context);
                        },
                      ),
                      onTap: () async {
                        final json = await FlowStorage.instance
                            .loadFlow(flow['id'] as int);
                        if (json != null) {
                          _controller.fromJson(json);
                          setState(() {});
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Flow "$name" loaded!')),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            icon: Icon(
              _isServerRunning ? Icons.cloud_off : Icons.cloud_upload,
              color: _isServerRunning ? Colors.red : Colors.green,
            ),
            tooltip: _isServerRunning ? 'Stop Server' : 'Start Server (8080)',
            onPressed: () async {
              if (_isServerRunning) {
                await _server.stop();
                setState(() => _isServerRunning = false);
              } else {
                try {
                  await _server.start(port: 8080);
                  setState(() => _isServerRunning = true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to start: $e')),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save Flow',
            onPressed: () => _showSaveDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Load Flow',
            onPressed: () => _showLoadDialog(context),
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
                Positioned(
                  top: 12,
                  left: 136,
                  child: InkWell(
                    onTap: () {
                      final count = _controller.nodes.length;
                      _controller.addNode(
                        type: NodeType.defaultNode,
                        label: 'Telegram',
                        position: Offset(300 + count * 50, 100 + count * 50),
                        size: const Size(100, 100),
                        data: const {
                          'definitionType': 'telegram',
                          'action': 'sendMessage',
                        },
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: const Icon(Icons.telegram, color: Colors.blue, size: 28),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 198,
                  child: InkWell(
                    onTap: () {
                      final count = _controller.nodes.length;
                      _controller.addNode(
                        type: NodeType.defaultNode,
                        label: 'Gemini',
                        position: Offset(400 + count * 50, 100 + count * 50),
                        size: const Size(100, 100),
                        data: const {
                          'definitionType': 'gemini',
                        },
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple, width: 2),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 28),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 260,
                  child: InkWell(
                    onTap: () {
                      final count = _controller.nodes.length;
                      _controller.addNode(
                        type: NodeType.trigger,
                        label: 'Output',
                        position: Offset(500 + count * 50, 100 + count * 50),
                        size: const Size(100, 100),
                        data: const {
                          'direction': 'output',
                          'definitionType': 'output',
                          'label': 'Result',
                        },
                      );
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: const Icon(Icons.output_rounded, color: Colors.green, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width >= 800)
            NodePropertiesPanel(controller: _controller),
        ],
      ),
      bottomSheet: MediaQuery.of(context).size.width < 800
          ? AnimatedBuilder(
              animation: _controller.selection,
              builder: (context, _) {
                final selectedIds = _controller.selection.selectedNodeIds;
                if (selectedIds.isEmpty) return const SizedBox.shrink();

                return BottomSheet(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onClosing: () {},
                  enableDrag: false,
                  builder: (context) {
                    return ExpandableBottomSheet(
                      builder: (context, scrollController) {
                        return NodePropertiesPanel(
                          controller: _controller,
                          width: double.infinity,
                          scrollController: scrollController,
                        );
                      },
                    );
                  },
                );
              },
            )
          : null,
    );
  }
}
