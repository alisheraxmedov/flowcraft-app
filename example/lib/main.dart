import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  runApp(const FlowCraftExampleApp());
}

class FlowCraftExampleApp extends StatefulWidget {
  const FlowCraftExampleApp({super.key});

  @override
  State<FlowCraftExampleApp> createState() => _FlowCraftExampleAppState();
}

class _FlowCraftExampleAppState extends State<FlowCraftExampleApp> {
  late FlowController _controller;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _controller = _buildDemoController();
    _scheduleFitView();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  FlowController _buildDemoController() {
    final controller = FlowController();

    final trigger = controller.addNode(
      type: NodeType.input,
      label: 'Trigger',
      position: const Offset(100, 120),
      data: const {
        'type': 'Webhook',
        'status': 'Active',
      },
    );

    final transform = controller.addNode(
      label: 'Transform',
      position: const Offset(380, 110),
      data: const {
        'action': 'Normalize payload',
        'runtime': '42ms',
      },
    );

    final approval = controller.addNode(
      label: 'Approval',
      position: const Offset(700, 240),
      data: const {
        'owner': 'Ops',
        'sla': '2h',
      },
    );

    final deliver = controller.addNode(
      type: NodeType.output,
      label: 'Deliver',
      position: const Offset(980, 110),
      data: const {
        'target': 'CRM',
        'mode': 'Sync',
      },
    );

    controller.addEdge(
      sourceNodeId: trigger.id,
      targetNodeId: transform.id,
      sourceHandleId: _handleId(trigger, HandlePosition.right),
      targetHandleId: _handleId(transform, HandlePosition.left),
      style: const EdgeStyle(
        color: Color(0xFF2F80ED),
        thickness: 3,
        animated: true,
        dashPattern: [10, 6],
        label: 'ingest',
      ),
    );

    controller.addEdge(
      sourceNodeId: transform.id,
      targetNodeId: approval.id,
      sourceHandleId: _handleId(transform, HandlePosition.right),
      targetHandleId: _handleId(approval, HandlePosition.left),
      style: const EdgeStyle(
        color: Color(0xFFF2994A),
        thickness: 3,
        edgeType: EdgeType.smoothStep,
        animated: true,
        dashPattern: [12, 6],
        label: 'review',
      ),
    );

    controller.addEdge(
      sourceNodeId: approval.id,
      targetNodeId: deliver.id,
      sourceHandleId: _handleId(approval, HandlePosition.right),
      targetHandleId: _handleId(deliver, HandlePosition.left),
      style: const EdgeStyle(
        color: Color(0xFF27AE60),
        thickness: 3,
        edgeType: EdgeType.straight,
        animated: true,
        dashPattern: [8, 5],
        label: 'ship',
      ),
    );

    return controller;
  }

  String _handleId(FlowNode node, HandlePosition position) {
    return node.handles.firstWhere((handle) => handle.position == position).id;
  }

  void _scheduleFitView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitView();
    });
  }

  void _fitView() {
    final size = MediaQuery.sizeOf(context);
    _controller.fitView(Size(size.width, size.height - kToolbarHeight));
  }

  void _resetDemo() {
    final oldController = _controller;
    setState(() {
      _controller = _buildDemoController();
    });
    oldController.dispose();
    _scheduleFitView();
  }

  void _addNode() {
    final previousNode =
        _controller.nodes.isEmpty ? null : _controller.nodes.last;
    final nodeNumber = _controller.nodes.length + 1;
    final row = (_controller.nodes.length - 1) ~/ 4;
    final column = (_controller.nodes.length - 1) % 4;

    final newNode = _controller.addNode(
      label: 'Step $nodeNumber',
      position: Offset(
        120 + (column * 250),
        420 + (row * 140),
      ),
      data: {
        'status': 'Draft',
        'index': nodeNumber,
      },
    );

    if (previousNode != null) {
      _controller.addEdge(
        sourceNodeId: previousNode.id,
        targetNodeId: newNode.id,
        sourceHandleId: _handleId(previousNode, HandlePosition.right),
        targetHandleId: _handleId(newNode, HandlePosition.left),
        style: const EdgeStyle(
          color: Color(0xFF9B51E0),
          thickness: 3,
          animated: true,
          dashPattern: [9, 5],
          label: 'new step',
        ),
      );
    }

    _showMessage('Added ${newNode.label}');
    _scheduleFitView();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FlowCraft Demo',

      theme: ThemeData(
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        colorSchemeSeed: _darkMode
            ? const Color(0xFF0F766E)
            : const Color(0xFF2563EB),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlowCraft Demo'),
          actions: [
            IconButton(
              tooltip: 'Add node',
              onPressed: _addNode,
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: _controller.canRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            IconButton(
              tooltip: 'Fit view',
              onPressed: _fitView,
              icon: const Icon(Icons.fit_screen_outlined),
            ),
            IconButton(
              tooltip: 'Reset demo',
              onPressed: _resetDemo,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: _darkMode
                  ? 'Switch to light theme'
                  : 'Switch to dark theme',
              onPressed: () {
                setState(() {
                  _darkMode = !_darkMode;
                });
              },
              icon: Icon(
                _darkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ],
        ),
        body: FlowCanvas(
          controller: _controller,
          theme: _darkMode ? FlowTheme.dark() : FlowTheme.light(),
          showMiniMap: true,
          showControls: true,
          onNodeTap: (nodeId) => _showMessage('Node tapped: $nodeId'),
          onEdgeTap: (edgeId) => _showMessage('Edge tapped: $edgeId'),
          onNodeAdded: (nodeId) => _showMessage('Node added: $nodeId'),
          overlays: const [
            _DemoHelpCard(),
          ],
        ),
      ),
    );
  }
}

class _DemoHelpCard extends StatelessWidget {
  const _DemoHelpCard();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD111827),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: DefaultTextStyle(
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Try it live',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text('Drag nodes to move them around the canvas.'),
                Text('Tap a node to select it, then tap × to delete.'),
                Text('Use the bottom-left controls to zoom and fit view.'),
                Text('Use the AppBar to add nodes, undo/redo, or reset.'),
                Text('The minimap in the bottom-right shows graph coverage.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
