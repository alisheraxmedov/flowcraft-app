import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  runApp(const FlowCraftExampleApp());
}

class FlowCraftExampleApp extends StatelessWidget {
  const FlowCraftExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppShell();
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  bool _darkMode = true;

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
      home: _HomePage(
        darkMode: _darkMode,
        onToggleTheme: () => setState(() => _darkMode = !_darkMode),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.darkMode,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late FlowController _controller;
  String? _selectedNodeId;
  String? _selectedEdgeId;

  @override
  void initState() {
    super.initState();
    _controller = _buildDemoController();
    _controller.addListener(_onControllerChanged);
    _scheduleFitView();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  FlowController _buildDemoController() {
    final controller = FlowController(snapToGrid: true, gridSnap: 20);

    // Add independent demo nodes (NOT auto-connected)
    controller.addNode(
      type: NodeType.input,
      label: 'Trigger',
      position: const Offset(100, 120),
      data: const {'type': 'Webhook', 'status': 'Active'},
    );

    controller.addNode(
      label: 'Transform',
      position: const Offset(400, 120),
      data: const {'action': 'Normalize', 'runtime': '42ms'},
    );

    controller.addNode(
      label: 'Approval',
      position: const Offset(700, 260),
      data: const {'owner': 'Ops', 'sla': '2h'},
    );

    controller.addNode(
      type: NodeType.output,
      label: 'Deliver',
      position: const Offset(1000, 120),
      data: const {'target': 'CRM', 'mode': 'Sync'},
    );

    // NO edges — user will drag from handles to connect them!
    return controller;
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
    oldController.removeListener(_onControllerChanged);
    setState(() {
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _controller = _buildDemoController();
      _controller.addListener(_onControllerChanged);
    });
    oldController.dispose();
    _scheduleFitView();
  }

  void _addNode() {
    final nodeNumber = _controller.nodes.length + 1;
    final row = (_controller.nodes.length) ~/ 4;
    final column = (_controller.nodes.length) % 4;

    final newNode = _controller.addNode(
      label: 'Step $nodeNumber',
      position: Offset(
        100 + (column * 280),
        400 + (row * 140),
      ),
      data: {'status': 'Draft', 'index': nodeNumber},
    );

    // New node is INDEPENDENT — no auto-connect!
    _showMessage('Added ${newNode.label} — drag handles to connect');
    _scheduleFitView();
  }

  void _onNodeTap(String nodeId) {
    setState(() {
      _selectedEdgeId = null;
      _selectedNodeId = _selectedNodeId == nodeId ? null : nodeId;
    });
  }

  void _onEdgeTap(String edgeId) {
    setState(() {
      _selectedNodeId = null;
      _selectedEdgeId = _selectedEdgeId == edgeId ? null : edgeId;
    });
  }

  FlowNode? get _selectedNode {
    if (_selectedNodeId == null) return null;
    try {
      return _controller.nodes.firstWhere((n) => n.id == _selectedNodeId);
    } catch (_) {
      return null;
    }
  }

  FlowEdge? get _selectedEdge {
    if (_selectedEdgeId == null) return null;
    try {
      return _controller.edges.firstWhere((e) => e.id == _selectedEdgeId);
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final selectedNode = _selectedNode;
    final selectedEdge = _selectedEdge;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowCraft Demo'),
        actions: [
          // Snap-to-grid toggle
          IconButton(
            tooltip: _controller.snapToGrid
                ? 'Disable snap-to-grid'
                : 'Enable snap-to-grid',
            onPressed: () {
              setState(() {
                _controller.snapToGrid = !_controller.snapToGrid;
              });
            },
            icon: Icon(
              _controller.snapToGrid
                  ? Icons.grid_on_rounded
                  : Icons.grid_off_rounded,
            ),
          ),
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
            tooltip: widget.darkMode
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.darkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main canvas
          Expanded(
            child: FlowCanvas(
              controller: _controller,
              theme: widget.darkMode ? FlowTheme.dark() : FlowTheme.light(),
              showMiniMap: true,
              showControls: true,
              onNodeTap: _onNodeTap,
              onEdgeTap: _onEdgeTap,
              onConnectionCreated: (edgeId) {
                _showMessage('Connection created!');
              },
              onNodeAdded: (nodeId) =>
                  _showMessage('Node added: $nodeId'),
            ),
          ),

          // Node edit panel
          if (selectedNode != null)
            _NodeEditPanel(
              key: ValueKey(selectedNode.id),
              node: selectedNode,
              controller: _controller,
              darkMode: widget.darkMode,
              onClose: () => setState(() => _selectedNodeId = null),
              onShowMessage: _showMessage,
            ),

          // Edge edit panel
          if (selectedEdge != null && selectedNode == null)
            _EdgeEditPanel(
              key: ValueKey(selectedEdge.id),
              edge: selectedEdge,
              controller: _controller,
              darkMode: widget.darkMode,
              onClose: () => setState(() => _selectedEdgeId = null),
              onShowMessage: _showMessage,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node Edit Side Panel
// ---------------------------------------------------------------------------

class _NodeEditPanel extends StatefulWidget {
  const _NodeEditPanel({
    super.key,
    required this.node,
    required this.controller,
    required this.darkMode,
    required this.onClose,
    required this.onShowMessage,
  });

  final FlowNode node;
  final FlowController controller;
  final bool darkMode;
  final VoidCallback onClose;
  final void Function(String message) onShowMessage;

  @override
  State<_NodeEditPanel> createState() => _NodeEditPanelState();
}

class _NodeEditPanelState extends State<_NodeEditPanel> {
  late TextEditingController _labelController;
  late TextEditingController _newKeyController;
  late TextEditingController _newValueController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.node.label);
    _newKeyController = TextEditingController();
    _newValueController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _newKeyController.dispose();
    _newValueController.dispose();
    super.dispose();
  }

  void _renameNode() {
    final newLabel = _labelController.text.trim();
    if (newLabel.isEmpty) return;
    widget.controller.renameNode(widget.node.id, newLabel);
    widget.onShowMessage('Renamed to "$newLabel"');
  }

  void _changeNodeType(NodeType type) {
    widget.controller.setNodeType(widget.node.id, type);
    widget.onShowMessage('Type → ${type.name}');
  }

  void _addField() {
    final key = _newKeyController.text.trim();
    final value = _newValueController.text.trim();
    if (key.isEmpty) return;
    widget.controller.addNodeField(
      widget.node.id,
      key: key,
      value: value.isEmpty ? '—' : value,
    );
    _newKeyController.clear();
    _newValueController.clear();
    widget.onShowMessage('Added field "$key"');
  }

  void _editField(String key, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit "$key"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            widget.controller.addNodeField(
              widget.node.id,
              key: key,
              value: controller.text.trim(),
            );
            Navigator.of(ctx).pop();
            widget.onShowMessage('Updated "$key"');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.addNodeField(
                widget.node.id,
                key: key,
                value: controller.text.trim(),
              );
              Navigator.of(ctx).pop();
              widget.onShowMessage('Updated "$key"');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeField(String key) {
    widget.controller.removeNodeField(widget.node.id, key);
    widget.onShowMessage('Removed "$key"');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _PanelHeader(
            title: 'Edit Node',
            icon: Icons.edit_note_rounded,
            onClose: widget.onClose,
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Name
                _SectionTitle(title: 'Name', icon: Icons.label_outline),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _labelController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Node name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _renameNode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _renameNode,
                      child: const Text('Rename'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Type
                _SectionTitle(
                    title: 'Type', icon: Icons.category_outlined),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NodeType.values
                      .where((t) => t != NodeType.custom)
                      .map((type) {
                    final isSelected = widget.node.type == type;
                    return ChoiceChip(
                      label: Text(_nodeTypeLabel(type)),
                      selected: isSelected,
                      onSelected: (_) => _changeNodeType(type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Fields
                _SectionTitle(
                    title: 'Data Fields', icon: Icons.data_object_rounded),
                const SizedBox(height: 8),

                if (widget.node.data.isEmpty)
                  Text(
                    'No fields',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...widget.node.data.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.key,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        )),
                                    Text('${entry.value}',
                                        style:
                                            theme.textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editField(
                                    entry.key, '${entry.value}'),
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () =>
                                    _removeField(entry.key),
                                icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colorScheme.error),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        ),
                      )),

                const SizedBox(height: 12),

                // Add field
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Field',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          )),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newKeyController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Key',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newValueController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Value',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _addField(),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _addField,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Field'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Delete
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.controller.removeNode(widget.node.id);
                      widget.onClose();
                      widget.onShowMessage(
                          'Deleted "${widget.node.label}"');
                    },
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 18),
                    label: const Text('Delete Node'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nodeTypeLabel(NodeType type) {
    switch (type) {
      case NodeType.defaultNode:
        return 'Default';
      case NodeType.input:
        return 'Input';
      case NodeType.output:
        return 'Output';
      case NodeType.custom:
        return 'Custom';
    }
  }
}

// ---------------------------------------------------------------------------
// Edge Edit Side Panel
// ---------------------------------------------------------------------------

class _EdgeEditPanel extends StatelessWidget {
  const _EdgeEditPanel({
    super.key,
    required this.edge,
    required this.controller,
    required this.darkMode,
    required this.onClose,
    required this.onShowMessage,
  });

  final FlowEdge edge;
  final FlowController controller;
  final bool darkMode;
  final VoidCallback onClose;
  final void Function(String message) onShowMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _PanelHeader(
            title: 'Edit Edge',
            icon: Icons.linear_scale_rounded,
            onClose: onClose,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Edge Type
                _SectionTitle(
                    title: 'Edge Type', icon: Icons.route_rounded),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EdgeType.values.map((type) {
                    final isSelected = edge.style.edgeType == type;
                    return ChoiceChip(
                      label: Text(_edgeTypeLabel(type)),
                      selected: isSelected,
                      onSelected: (_) {
                        controller.updateEdgeStyle(
                          edge.id,
                          edge.style.copyWith(edgeType: type),
                        );
                        onShowMessage('Edge type → ${type.name}');
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Animated toggle
                _SectionTitle(
                    title: 'Animation',
                    icon: Icons.animation_rounded),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Animated'),
                  value: edge.style.animated,
                  dense: true,
                  onChanged: (v) {
                    controller.updateEdgeStyle(
                      edge.id,
                      edge.style.copyWith(animated: v),
                    );
                  },
                ),

                // Arrow toggle
                SwitchListTile(
                  title: const Text('Show Arrow'),
                  value: edge.style.showArrow,
                  dense: true,
                  onChanged: (v) {
                    controller.updateEdgeStyle(
                      edge.id,
                      edge.style.copyWith(showArrow: v),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Thickness
                _SectionTitle(
                    title: 'Thickness',
                    icon: Icons.line_weight_rounded),
                const SizedBox(height: 8),
                Slider(
                  value: edge.style.thickness,
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: edge.style.thickness.toStringAsFixed(0),
                  onChanged: (v) {
                    controller.updateEdgeStyle(
                      edge.id,
                      edge.style.copyWith(thickness: v),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Edge ID
                _SectionTitle(
                    title: 'Edge ID',
                    icon: Icons.fingerprint_rounded),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    edge.id,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Delete
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      controller.removeEdge(edge.id);
                      onClose();
                      onShowMessage('Deleted edge');
                    },
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 18),
                    label: const Text('Delete Edge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _edgeTypeLabel(EdgeType type) {
    switch (type) {
      case EdgeType.bezier:
        return 'Bezier';
      case EdgeType.smoothStep:
        return 'Smooth Step';
      case EdgeType.step:
        return 'Step';
      case EdgeType.straight:
        return 'Straight';
    }
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.icon,
    required this.onClose,
  });

  final String title;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(28, 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
