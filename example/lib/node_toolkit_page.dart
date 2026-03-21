import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

/// A comprehensive toolkit page for testing all 13 node types
/// with pre-built demo workflows and a node palette.
class NodeToolkitPage extends StatefulWidget {
  const NodeToolkitPage({super.key});

  @override
  State<NodeToolkitPage> createState() => _NodeToolkitPageState();
}

class _NodeToolkitPageState extends State<NodeToolkitPage> {
  late FlowController _controller;
  String _activeDemo = 'data_pipeline';
  bool _showPalette = true;

  @override
  void initState() {
    super.initState();
    _controller = _buildDemo(_activeDemo);
    _scheduleFit();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.fitView(MediaQuery.sizeOf(context));
    });
  }

  void _registerAllNodes(FlowController c) {
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
  }

  FlowHandle _right(FlowNode n) =>
      n.handles.firstWhere((h) => h.position == HandlePosition.right);
  FlowHandle _left(FlowNode n) =>
      n.handles.firstWhere((h) => h.position == HandlePosition.left);

  void _connect(FlowController c, FlowNode from, FlowNode to) {
    c.addEdge(
      sourceNodeId: from.id,
      targetNodeId: to.id,
      sourceHandleId: _right(from).id,
      targetHandleId: _left(to).id,
    );
  }

  FlowController _buildDemo(String demoId) {
    final c = FlowController(snapToGrid: true, gridSnap: 20);
    _registerAllNodes(c);

    switch (demoId) {
      case 'data_pipeline':
        _buildDataPipeline(c);
        break;
      case 'error_handling':
        _buildErrorHandling(c);
        break;
      case 'webhook_flow':
        _buildWebhookFlow(c);
        break;
      case 'ai_workflow':
        _buildAiWorkflow(c);
        break;
      case 'empty':
        break;
    }

    return c;
  }

  // ── Demo 1: Data Pipeline ─────────────────────────────────────────────────

  void _buildDataPipeline(FlowController c) {
    final trigger = c.addNode(
      type: NodeType.trigger,
      label: 'Start',
      position: const Offset(40, 140),
      size: const Size(120, 60),
      data: const {
        'direction': 'input',
        'definitionType': 'trigger',
        'payload': {
          'users': ['Alice', 'Bob', 'Charlie'],
          'project': 'FlowCraft',
          'version': 3,
        },
      },
    );

    final variable = c.addNode(
      label: 'Set Vars',
      position: const Offset(280, 140),
      data: const {
        'definitionType': 'variable',
        'operation': 'set',
        'variables': {'status': 'active', 'env': 'production'},
      },
    );

    final transform = c.addNode(
      label: 'Transform',
      position: const Offset(520, 140),
      data: const {
        'definitionType': 'transform',
        'operation': 'set',
        'fields': {'processed': true, 'step': 'transformed'},
      },
    );

    final loop = c.addNode(
      label: 'Loop Users',
      position: const Offset(760, 140),
      data: const {
        'definitionType': 'loop',
        'listField': 'users',
        'maxIterations': 50,
      },
    );

    final delay = c.addNode(
      label: 'Wait 500ms',
      position: const Offset(1000, 140),
      data: const {
        'definitionType': 'delay',
        'duration': 500,
      },
    );

    final output = c.addNode(
      type: NodeType.trigger,
      label: 'Result',
      position: const Offset(1240, 140),
      size: const Size(120, 60),
      data: const {
        'direction': 'output',
        'definitionType': 'output',
        'label': 'Pipeline Result',
      },
    );

    _connect(c, trigger, variable);
    _connect(c, variable, transform);
    _connect(c, transform, loop);
    _connect(c, loop, delay);
    _connect(c, delay, output);
  }

  // ── Demo 2: Error Handling ────────────────────────────────────────────────

  void _buildErrorHandling(FlowController c) {
    final trigger = c.addNode(
      type: NodeType.trigger,
      label: 'Start',
      position: const Offset(40, 180),
      size: const Size(120, 60),
      data: const {
        'direction': 'input',
        'definitionType': 'trigger',
        'payload': {
          'url': 'https://httpbin.org/status/500',
          'action': 'test_error',
        },
      },
    );

    final http = c.addNode(
      label: 'HTTP Call',
      position: const Offset(300, 180),
      data: const {
        'definitionType': 'http_request',
        'url': 'https://httpbin.org/json',
        'method': 'GET',
      },
    );

    final errorHandler = c.addNode(
      label: 'Catch Error',
      position: const Offset(580, 180),
      data: const {
        'definitionType': 'error_handler',
        'errorField': '_error',
        'continueOnError': true,
        'fallbackValue': {'status': 'error_caught', 'fallback': true},
      },
    );

    final condition = c.addNode(
      label: 'Check Status',
      position: const Offset(860, 60),
      data: const {
        'definitionType': 'condition',
        'field': 'statusCode',
        'operator': 'equals',
        'value': '200',
      },
    );

    final transform = c.addNode(
      label: 'Format OK',
      position: const Offset(1140, 60),
      data: const {
        'definitionType': 'transform',
        'operation': 'set',
        'fields': {'result': 'success', 'handled': true},
      },
    );

    final output = c.addNode(
      type: NodeType.trigger,
      label: 'Output',
      position: const Offset(1380, 180),
      size: const Size(120, 60),
      data: const {
        'direction': 'output',
        'definitionType': 'output',
        'label': 'Final',
      },
    );

    _connect(c, trigger, http);
    _connect(c, http, errorHandler);
    _connect(c, errorHandler, condition);
    _connect(c, condition, transform);
    _connect(c, transform, output);
  }

  // ── Demo 3: Webhook Flow ──────────────────────────────────────────────────

  void _buildWebhookFlow(FlowController c) {
    final webhook = c.addNode(
      type: NodeType.trigger,
      label: 'Webhook',
      position: const Offset(40, 160),
      size: const Size(120, 60),
      data: const {
        'direction': 'input',
        'definitionType': 'webhook',
        'method': 'POST',
        'path': '/api/incoming',
        'testPayload': {
          'event': 'user.created',
          'userId': 1001,
          'email': 'test@example.com',
        },
      },
    );

    final variable = c.addNode(
      label: 'Enrich',
      position: const Offset(300, 160),
      data: const {
        'definitionType': 'variable',
        'operation': 'set',
        'variables': {'source': 'webhook', 'processed_at': '2026-03-20'},
      },
    );

    final condition = c.addNode(
      label: 'Check Event',
      position: const Offset(560, 160),
      data: const {
        'definitionType': 'condition',
        'field': 'event',
        'operator': 'contains',
        'value': 'user',
      },
    );

    final merge = c.addNode(
      label: 'Merge',
      position: const Offset(820, 160),
      data: const {
        'definitionType': 'merge',
        'strategy': 'merge',
      },
    );

    final output = c.addNode(
      type: NodeType.trigger,
      label: 'Done',
      position: const Offset(1060, 160),
      size: const Size(120, 60),
      data: const {
        'direction': 'output',
        'definitionType': 'output',
        'label': 'Webhook Result',
      },
    );

    _connect(c, webhook, variable);
    _connect(c, variable, condition);
    _connect(c, condition, merge);
    _connect(c, merge, output);
  }

  // ── Demo 4: AI Workflow ───────────────────────────────────────────────────

  void _buildAiWorkflow(FlowController c) {
    final trigger = c.addNode(
      type: NodeType.trigger,
      label: 'Input',
      position: const Offset(40, 180),
      size: const Size(120, 60),
      data: const {
        'direction': 'input',
        'definitionType': 'trigger',
        'payload': {
          'topic': 'Flutter state management',
          'language': 'English',
        },
      },
    );

    final openai = c.addNode(
      label: 'OpenAI',
      position: const Offset(300, 80),
      data: const {
        'definitionType': 'openai',
        'apiKey': '',
        'model': '',
        'systemMessage': '',
        'userMessage': 'Explain {{topic}} in {{language}}',
        'temperature': 0.7,
        'maxTokens': 512,
      },
    );

    final gemini = c.addNode(
      label: 'Gemini',
      position: const Offset(300, 300),
      data: const {
        'definitionType': 'gemini',
        'apiKey': '',
        'model': '',
        'systemInstruction': '',
        'userMessage': 'Summarize {{topic}} in 3 bullet points',
        'temperature': 0.5,
        'maxOutputTokens': 256,
      },
    );

    final merge = c.addNode(
      label: 'Combine',
      position: const Offset(600, 180),
      data: const {
        'definitionType': 'merge',
        'strategy': 'merge',
      },
    );

    final transform = c.addNode(
      label: 'Format',
      position: const Offset(860, 180),
      data: const {
        'definitionType': 'transform',
        'operation': 'set',
        'fields': {'combined': true, 'type': 'ai_comparison'},
      },
    );

    final output = c.addNode(
      type: NodeType.trigger,
      label: 'Report',
      position: const Offset(1100, 180),
      size: const Size(120, 60),
      data: const {
        'direction': 'output',
        'definitionType': 'output',
        'label': 'AI Report',
      },
    );

    _connect(c, trigger, openai);
    _connect(c, trigger, gemini);
    _connect(c, openai, merge);
    _connect(c, gemini, merge);
    _connect(c, merge, transform);
    _connect(c, transform, output);
  }

  // ── Execution ─────────────────────────────────────────────────────────────

  Future<void> _execute() async {
    if (_controller.isExecuting) return;
    setState(() {});

    final result = await _controller.executeWorkflow();
    if (!mounted) return;

    final formatted = const JsonEncoder.withIndent('  ').convert(
      result.nodeResults.map(
        (k, v) => MapEntry(k.substring(0, 8), {
          'status': v.status.name,
          'ms': v.duration.inMilliseconds,
          'output': v.outputData,
          if (v.errorMessage != null) 'error': v.errorMessage,
        }),
      ),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isSuccess ? Icons.check_circle : Icons.error,
              color: result.isSuccess
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFFEF5350),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.isSuccess
                    ? 'Done (${result.duration.inMilliseconds}ms)'
                    : 'Failed',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450,
          child: SingleChildScrollView(
            child: SelectableText(
              formatted,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _controller.resetRuntimeStates();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _switchDemo(String demoId) {
    if (_activeDemo == demoId) return;
    final old = _controller;
    setState(() {
      _activeDemo = demoId;
      _controller = _buildDemo(demoId);
    });
    old.dispose();
    _scheduleFit();
  }

  // ── Node palette: add any node type ───────────────────────────────────────

  static const _nodeTemplates = <_NodeTemplate>[
    _NodeTemplate('Trigger', 'trigger', NodeType.trigger, Color(0xFFFF9800),
        Icons.play_circle_outline, Size(120, 60), true),
    _NodeTemplate('Webhook', 'webhook', NodeType.trigger, Color(0xFF7E57C2),
        Icons.webhook, Size(120, 60), true),
    _NodeTemplate('HTTP Request', 'http_request', NodeType.defaultNode,
        Color(0xFF42A5F5), Icons.http_rounded, Size(160, 70), false),
    _NodeTemplate('Transform', 'transform', NodeType.defaultNode,
        Color(0xFF26A69A), Icons.transform_rounded, Size(160, 70), false),
    _NodeTemplate('Condition', 'condition', NodeType.defaultNode,
        Color(0xFFAB47BC), Icons.alt_route_rounded, Size(160, 70), false),
    _NodeTemplate('Variable', 'variable', NodeType.defaultNode,
        Color(0xFF5C6BC0), Icons.data_object_rounded, Size(160, 70), false),
    _NodeTemplate('Delay', 'delay', NodeType.defaultNode,
        Color(0xFFFF7043), Icons.timer_outlined, Size(160, 70), false),
    _NodeTemplate('Loop', 'loop', NodeType.defaultNode,
        Color(0xFF66BB6A), Icons.loop_rounded, Size(160, 70), false),
    _NodeTemplate('Merge', 'merge', NodeType.defaultNode,
        Color(0xFFEC407A), Icons.merge_rounded, Size(160, 70), false),
    _NodeTemplate('Error Handler', 'error_handler', NodeType.defaultNode,
        Color(0xFFEF5350), Icons.error_outline_rounded, Size(160, 70), false),
    _NodeTemplate('OpenAI', 'openai', NodeType.defaultNode,
        Color(0xFF00BFA5), Icons.psychology_rounded, Size(160, 70), false),
    _NodeTemplate('Gemini', 'gemini', NodeType.defaultNode,
        Color(0xFF1E88E5), Icons.auto_awesome_rounded, Size(160, 70), false),
    _NodeTemplate('Telegram', 'telegram', NodeType.defaultNode,
        Color(0xFF0088CC), Icons.send_rounded, Size(160, 70), false),
    _NodeTemplate('Output', 'output', NodeType.trigger, Color(0xFF66BB6A),
        Icons.output_rounded, Size(120, 60), true),
  ];

  void _addNodeFromTemplate(_NodeTemplate t) {
    final count = _controller.nodes.length;
    final row = count ~/ 3;
    final col = count % 3;

    final data = <String, dynamic>{
      'definitionType': t.defType,
    };
    if (t.isTriggerShape) {
      data['direction'] = t.defType == 'output' ? 'output' : 'input';
    }

    _controller.addNode(
      type: t.nodeType,
      label: t.label,
      position: Offset(100 + col * 260, 400 + row * 120),
      size: t.size,
      data: data,
    );
    setState(() {});
    _scheduleFit();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Toolkit'),
        centerTitle: true,
        actions: [
          // Demo switcher
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Demo Workflows',
            onSelected: _switchDemo,
            itemBuilder: (_) => [
              _demoItem('data_pipeline', 'Data Pipeline',
                  'Trigger → Variable → Transform → Loop → Delay → Output'),
              _demoItem('error_handling', 'Error Handling',
                  'Trigger → HTTP → ErrorHandler → Condition → Output'),
              _demoItem('webhook_flow', 'Webhook Flow',
                  'Webhook → Variable → Condition → Merge → Output'),
              _demoItem('ai_workflow', 'AI Workflow',
                  'Trigger → OpenAI + Gemini → Merge → Output'),
              _demoItem('empty', 'Empty Canvas', 'Start from scratch'),
            ],
          ),

          const SizedBox(width: 4),

          // Toggle palette
          IconButton(
            icon: Icon(
              _showPalette
                  ? Icons.view_sidebar_rounded
                  : Icons.view_sidebar_outlined,
            ),
            tooltip: 'Toggle Node Palette',
            onPressed: () => setState(() => _showPalette = !_showPalette),
          ),

          const SizedBox(width: 8),

          // Reset
          OutlinedButton.icon(
            onPressed: () {
              _controller.resetRuntimeStates();
              setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
          ),

          const SizedBox(width: 8),

          // Execute
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _controller.isExecuting ? null : _execute,
              icon: _controller.isExecuting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label:
                  Text(_controller.isExecuting ? 'Running...' : 'Execute'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Node Palette (left sidebar)
          if (_showPalette)
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                border: Border(
                  right: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Add Node',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _nodeTemplates.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (_, index) {
                        final t = _nodeTemplates[index];
                        return _PaletteItem(
                          template: t,
                          onTap: () => _addNodeFromTemplate(t),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Canvas
          Expanded(
            child: FlowCanvas(
              controller: _controller,
              theme: isDark ? FlowTheme.dark() : FlowTheme.light(),
              showMiniMap: false,
              showControls: true,
              overlays: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _demoBadge(_activeDemo),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Node Properties Panel (right sidebar)
          NodePropertiesPanel(controller: _controller),
        ],
      ),
    );
  }

  PopupMenuItem<String> _demoItem(
      String id, String title, String subtitle) {
    return PopupMenuItem(
      value: id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontWeight: _activeDemo == id
                    ? FontWeight.w700
                    : FontWeight.w500,
              )),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  String _demoBadge(String demoId) {
    switch (demoId) {
      case 'data_pipeline':
        return '📊 Data Pipeline';
      case 'error_handling':
        return '🛡️ Error Handling';
      case 'webhook_flow':
        return '🔗 Webhook Flow';
      case 'ai_workflow':
        return '🤖 AI Workflow';
      case 'empty':
        return '📋 Empty Canvas';
      default:
        return demoId;
    }
  }
}

// ── Palette Item Widget ─────────────────────────────────────────────────────

class _PaletteItem extends StatelessWidget {
  const _PaletteItem({required this.template, required this.onTap});

  final _NodeTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: template.color.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(template.icon, color: template.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: template.color,
                  ),
                ),
              ),
              Icon(Icons.add_rounded,
                  size: 16,
                  color: template.color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Node Template ───────────────────────────────────────────────────────────

class _NodeTemplate {
  const _NodeTemplate(
    this.label,
    this.defType,
    this.nodeType,
    this.color,
    this.icon,
    this.size,
    this.isTriggerShape,
  );

  final String label;
  final String defType;
  final NodeType nodeType;
  final Color color;
  final IconData icon;
  final Size size;
  final bool isTriggerShape;
}
