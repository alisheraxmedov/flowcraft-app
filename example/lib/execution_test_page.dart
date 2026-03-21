import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

/// A dedicated page for testing workflow execution with pre-connected nodes.
class ExecutionTestPage extends StatefulWidget {
  const ExecutionTestPage({super.key});

  @override
  State<ExecutionTestPage> createState() => _ExecutionTestPageState();
}

class _ExecutionTestPageState extends State<ExecutionTestPage> {
  late FlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildExecutionDemo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.fitView(MediaQuery.sizeOf(context));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  FlowController _buildExecutionDemo() {
    final c = FlowController(snapToGrid: true, gridSnap: 20);

    // Register all built-in node definitions
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

    // ── Node 1: Trigger (input) ──
    final trigger = c.addNode(
      type: NodeType.trigger,
      label: 'Start',
      position: const Offset(80, 160),
      size: const Size(120, 60),
      data: const {
        'direction': 'input',
        'definitionType': 'trigger',
        'payload': {
          'name': 'FlowCraft',
          'version': '0.1.0',
          'count': 7,
        },
      },
    );

    // ── Node 2: Transform ──
    final transform = c.addNode(
      label: 'Transform',
      position: const Offset(360, 160),
      data: const {
        'definitionType': 'transform',
        'operation': 'set',
        'fields': {
          'processed': true,
          'engine': 'FlowCraft Engine',
        },
      },
    );

    // ── Node 3: Condition ──
    final condition = c.addNode(
      label: 'Check',
      position: const Offset(640, 160),
      data: const {
        'definitionType': 'condition',
        'field': 'processed',
        'operator': 'equals',
        'value': 'true',
      },
    );

    // ── Node 4: Output ──
    final output = c.addNode(
      type: NodeType.trigger,
      label: 'Result',
      position: const Offset(920, 160),
      size: const Size(120, 60),
      data: const {
        'direction': 'output',
        'definitionType': 'output',
        'label': 'Final Output',
      },
    );

    // ── Wire edges: Trigger → Transform → Condition → Output ──
    // Each node has 4 handles: top, bottom, left, right
    // We connect: source's RIGHT handle → target's LEFT handle

    FlowHandle rightHandle(FlowNode node) =>
        node.handles.firstWhere((h) => h.position == HandlePosition.right);
    FlowHandle leftHandle(FlowNode node) =>
        node.handles.firstWhere((h) => h.position == HandlePosition.left);

    c.addEdge(
      sourceNodeId: trigger.id,
      targetNodeId: transform.id,
      sourceHandleId: rightHandle(trigger).id,
      targetHandleId: leftHandle(transform).id,
    );

    c.addEdge(
      sourceNodeId: transform.id,
      targetNodeId: condition.id,
      sourceHandleId: rightHandle(transform).id,
      targetHandleId: leftHandle(condition).id,
    );

    c.addEdge(
      sourceNodeId: condition.id,
      targetNodeId: output.id,
      sourceHandleId: rightHandle(condition).id,
      targetHandleId: leftHandle(output).id,
    );

    return c;
  }

  Future<void> _execute() async {
    if (_controller.isExecuting) return;

    setState(() {});
    final result = await _controller.executeWorkflow();
    if (!mounted) return;

    // Show results dialog
    final formatted = const JsonEncoder.withIndent('  ').convert(
      result.nodeResults.map(
        (k, v) => MapEntry(k.substring(0, 8), {
          'status': v.status.name,
          'duration': '${v.duration.inMilliseconds}ms',
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
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              result.isSuccess
                  ? 'Success (${result.duration.inMilliseconds}ms)'
                  : 'Failed',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450,
          child: SingleChildScrollView(
            child: SelectableText(
              formatted,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _controller.resetRuntimeStates();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset States'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Test'),
        centerTitle: true,
        actions: [
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
              label: Text(
                  _controller.isExecuting ? 'Running...' : 'Execute'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () {
                _controller.resetRuntimeStates();
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
      body: FlowCanvas(
        controller: _controller,
        theme: isDark ? FlowTheme.dark() : FlowTheme.light(),
        showMiniMap: false,
        showControls: true,
        overlays: [
          // Legend
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pipeline',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _legendItem('Start', 'Trigger payload', const Color(0xFFFF9800)),
                  _legendItem('Transform', 'Add fields', const Color(0xFF42A5F5)),
                  _legendItem('Check', 'Condition', const Color(0xFFAB47BC)),
                  _legendItem('Result', 'Final output', const Color(0xFF66BB6A)),
                  const Divider(height: 16),
                  _statusLegend('Idle', const Color(0xFF90A4AE)),
                  _statusLegend('Running', const Color(0xFF42A5F5)),
                  _statusLegend('Success', const Color(0xFF66BB6A)),
                  _statusLegend('Error', const Color(0xFFEF5350)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String name, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text('$name — ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(desc, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
