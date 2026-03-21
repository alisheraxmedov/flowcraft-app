import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';

/// A side panel that displays editable configuration fields
/// for the currently selected node.
///
/// Reads [ParamDefinition] from the node's registered [NodeDefinition]
/// and renders appropriate form fields (text, number, boolean, select, etc.).
///
/// ```dart
/// NodePropertiesPanel(controller: myFlowController)
/// ```
class NodePropertiesPanel extends StatelessWidget {
  const NodePropertiesPanel({
    super.key,
    required this.controller,
    this.width = 300,
  });

  final FlowController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.selection,
      builder: (context, _) {
        final selectedIds = controller.selection.selectedNodeIds;
        if (selectedIds.isEmpty) {
          return _EmptyState(width: width);
        }

        final nodeId = selectedIds.first;
        final node = controller.graph.nodeById(nodeId);
        if (node == null) return _EmptyState(width: width);

        final defType = node.data['definitionType'] as String?;
        final definition = defType != null
            ? controller.nodeDefinitionRegistry.getDefinition(defType)
            : null;

        return _PanelContent(
          key: ValueKey(nodeId),
          controller: controller,
          nodeId: nodeId,
          nodeLabel: node.label,
          definition: definition,
          nodeData: node.data,
          width: width,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 36,
                color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'Select a node to\nedit its properties',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelContent extends StatefulWidget {
  const _PanelContent({
    super.key,
    required this.controller,
    required this.nodeId,
    required this.nodeLabel,
    required this.definition,
    required this.nodeData,
    required this.width,
  });

  final FlowController controller;
  final String nodeId;
  final String nodeLabel;
  final NodeDefinition? definition;
  final Map<String, dynamic> nodeData;
  final double width;

  @override
  State<_PanelContent> createState() => _PanelContentState();
}

class _PanelContentState extends State<_PanelContent> {
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    if (widget.definition == null) return;
    for (final param in widget.definition!.params) {
      final existing = widget.nodeData[param.name];
      final value = existing ?? param.defaultValue;
      String text;
      if (param.type == ParamType.json) {
        text = value is String ? value : const JsonEncoder.withIndent('  ').convert(value ?? {});
      } else {
        text = value?.toString() ?? '';
      }
      _textControllers[param.name] = TextEditingController(text: text);
    }
  }

  void _updateValue(String key, dynamic value) {
    widget.nodeData[key] = value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = widget.definition;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nodeLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                if (def != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${def.category} • ${def.typeId}',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Fields
          Expanded(
            child: def == null || def.params.isEmpty
                ? Center(
                    child: Text(
                      'No configurable parameters',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final param in def.params) ...[
                        _buildField(param, cs),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),

          // Node ID footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2)),
              ),
            ),
            child: Text(
              'ID: ${widget.nodeId.substring(0, 8)}…',
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(ParamDefinition param, ColorScheme cs) {
    Widget field;

    switch (param.type) {
      case ParamType.boolean:
        field = _boolField(param, cs);
        break;
      case ParamType.select:
        field = _selectField(param, cs);
        break;
      case ParamType.number:
        field = _textInputField(param, cs, isNumber: true);
        break;
      case ParamType.json:
      case ParamType.code:
        field = _multiLineField(param, cs);
        break;
      case ParamType.credential:
        field = _textInputField(param, cs, obscure: true);
        break;
      case ParamType.string:
        field = _textInputField(param, cs);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                param.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (param.type == ParamType.credential)
              Icon(Icons.lock_outline, size: 12,
                  color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
        if (param.description != null) ...[
          const SizedBox(height: 2),
          Text(
            param.description!,
            style: TextStyle(
              fontSize: 9,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  Widget _textInputField(ParamDefinition param, ColorScheme cs,
      {bool isNumber = false, bool obscure = false}) {
    final ctrl = _textControllers[param.name];
    if (ctrl == null) return const SizedBox.shrink();

    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(fontSize: 12, color: cs.onSurface),
      decoration: _inputDecoration(cs),
      onChanged: (value) {
        if (isNumber) {
          final parsed = num.tryParse(value);
          _updateValue(param.name, parsed ?? value);
        } else {
          _updateValue(param.name, value);
        }
      },
    );
  }

  Widget _multiLineField(ParamDefinition param, ColorScheme cs) {
    final ctrl = _textControllers[param.name];
    if (ctrl == null) return const SizedBox.shrink();

    return TextField(
      controller: ctrl,
      maxLines: 4,
      minLines: 2,
      style: TextStyle(
          fontSize: 11, fontFamily: 'monospace', color: cs.onSurface),
      decoration: _inputDecoration(cs),
      onChanged: (value) {
        if (param.type == ParamType.json) {
          try {
            final parsed = jsonDecode(value);
            _updateValue(param.name, parsed);
          } catch (_) {
            _updateValue(param.name, value);
          }
        } else {
          _updateValue(param.name, value);
        }
      },
    );
  }

  Widget _selectField(ParamDefinition param, ColorScheme cs) {
    final current = widget.nodeData[param.name]?.toString() ??
        param.defaultValue?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: DropdownButton<String>(
        value: param.options?.contains(current) == true ? current : null,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        hint: Text(current ?? 'Select…',
            style: TextStyle(fontSize: 12, color: cs.onSurface)),
        style: TextStyle(fontSize: 12, color: cs.onSurface),
        dropdownColor: cs.surfaceContainerHighest,
        items: (param.options ?? []).map((opt) {
          return DropdownMenuItem(value: opt, child: Text(opt));
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          _updateValue(param.name, value);
          setState(() {});
        },
      ),
    );
  }

  Widget _boolField(ParamDefinition param, ColorScheme cs) {
    final current = widget.nodeData[param.name] ??
        param.defaultValue ??
        false;
    final boolVal = current is bool ? current : current.toString() == 'true';

    return Row(
      children: [
        SizedBox(
          height: 20,
          width: 32,
          child: Switch.adaptive(
            value: boolVal,
            onChanged: (v) {
              _updateValue(param.name, v);
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6),
        Text(
          boolVal ? 'Yes' : 'No',
          style: TextStyle(fontSize: 11, color: cs.onSurface),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cs.primary),
      ),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
    );
  }
}
