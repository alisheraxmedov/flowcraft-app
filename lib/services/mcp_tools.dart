import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'diagram_spec.dart';

/// The tools the app's built-in MCP server exposes, in `tools/list` order.
///
/// Names, descriptions and schemas are deliberately identical to the ones
/// the legacy stdio bridge (`mcp_server/`) shipped, so prompts and agent
/// habits built against that bridge keep working verbatim. The one tool
/// that did *not* survive the move in-process is `flowcraft_launch`: it
/// only existed because the out-of-process bridge could find the app
/// closed. A server running inside the app can never be in that state.
const List<McpTool> flowcraftMcpTools = [
  McpTool(
    name: 'flowcraft_status',
    description:
        'Checks whether the FlowCraft desktop whiteboard app is running and '
        'reachable on this machine. Call this before flowcraft_draw if '
        'unsure.',
    inputSchema: _emptySchema,
    run: _runStatus,
  ),
  McpTool(
    name: 'flowcraft_draw',
    description:
        'Draws shapes on the canvas of the currently running FlowCraft '
        'desktop whiteboard app. Use it to visualize a class model, '
        'architecture diagram, or any other structure analyzed from the '
        "user's codebase — rectangles for classes/modules, text for labels, "
        'arrows for relations. Coordinates are canvas-space pixels; leave '
        'enough spacing between boxes (e.g. 260x120 rectangles, 80px gaps) '
        'so text does not overlap. Call flowcraft_status first if unsure '
        'whether the app is reachable.',
    inputSchema: _drawSchema,
    run: _runDraw,
  ),
  McpTool(
    name: 'flowcraft_clear',
    description: 'Removes every shape from the FlowCraft canvas.',
    inputSchema: _emptySchema,
    run: _runClear,
  ),
];

/// One MCP tool: its wire-level declaration plus the handler that applies
/// it to the live canvas.
///
/// Hand-rolled rather than reused from `package:dart_mcp` on purpose —
/// that package is stdio-only and has no place in the GUI app's pubspec
/// (see `CLAUDE.md`). A tool is only a name, a description, a JSON Schema
/// and a function, so declaring them as plain data costs nothing.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
  });

  final String name;
  final String description;

  /// JSON Schema for `arguments`, sent verbatim in `tools/list`.
  final Map<String, Object?> inputSchema;

  final McpToolResult Function(
    SketchController controller,
    Map<String, Object?> arguments,
  ) run;

  /// This tool's entry in a `tools/list` result.
  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// The outcome of one `tools/call`.
///
/// MCP reports *tool execution* failures inside an otherwise successful
/// response, flagged with `isError: true`, instead of as a JSON-RPC error.
/// That's what lets the model read the failure text and retry on its own;
/// a JSON-RPC error would be swallowed by the client's transport layer.
class McpToolResult {
  const McpToolResult(this.text) : isError = false;
  const McpToolResult.failed(this.text) : isError = true;

  final String text;
  final bool isError;

  Map<String, Object?> toJson() => {
        'content': [
          {'type': 'text', 'text': text},
        ],
        'isError': isError,
      };
}

const Map<String, Object?> _emptySchema = {
  'type': 'object',
  'properties': <String, Object?>{},
};

const Map<String, Object?> _drawSchema = {
  'type': 'object',
  'properties': {
    'mode': {
      'type': 'string',
      'description': '"add" appends to the existing canvas (default). '
          '"replace" clears the canvas first.',
    },
    'elements': {
      'type': 'array',
      'description': 'Shapes to draw, in canvas order (first = bottom).',
      'items': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'description': 'rectangle | ellipse | diamond | triangle | '
                'sticky | text | arrow | line',
          },
          'x': {
            'type': 'number',
            'description': 'Left edge (bounded shapes/text).',
          },
          'y': {
            'type': 'number',
            'description': 'Top edge (bounded shapes/text).',
          },
          'width': {
            'type': 'number',
            'description': 'Box width (bounded shapes).',
          },
          'height': {
            'type': 'number',
            'description': 'Box height (bounded shapes).',
          },
          'fromX': {'type': 'number', 'description': 'Start X (arrow/line).'},
          'fromY': {'type': 'number', 'description': 'Start Y (arrow/line).'},
          'toX': {'type': 'number', 'description': 'End X (arrow/line).'},
          'toY': {'type': 'number', 'description': 'End Y (arrow/line).'},
          'text': {'type': 'string', 'description': 'Label text, if any.'},
          'fontSize': {'type': 'number', 'description': 'Label font size.'},
          'strokeColor': {
            'type': 'string',
            'description': 'Hex color, e.g. "#1E1E1E". Defaults to black.',
          },
          'fillColor': {
            'type': 'string',
            'description': 'Hex color, optional. No fill if omitted.',
          },
        },
        'required': ['type'],
      },
    },
  },
  'required': ['elements'],
};

/// Reaching this handler at all proves the app is up — the server running
/// it *is* the app — so the only interesting part of the answer is how
/// much is currently on the canvas.
McpToolResult _runStatus(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final count = controller.elements.length;
  return McpToolResult(
    'FlowCraft app is running and reachable. The canvas currently holds '
    '$count element(s).',
  );
}

McpToolResult _runDraw(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final raw = arguments['elements'];
  if (raw is! List || raw.isEmpty) {
    return const McpToolResult.failed('No elements provided.');
  }
  // Anything that isn't the literal "replace" appends, matching the
  // bridge's behaviour — an unrecognized mode must never wipe the canvas.
  final mode = arguments['mode'] == 'replace' ? 'replace' : 'add';

  final elements = parseDiagramElements(raw);
  if (mode == 'replace') {
    controller.replaceAll(elements);
  } else {
    controller.addAll(elements);
  }
  return McpToolResult(
    'Drew ${elements.length} element(s) on FlowCraft (mode: $mode). '
    'Canvas now has ${controller.elements.length} element(s) total.',
  );
}

McpToolResult _runClear(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  controller.clear();
  return const McpToolResult('Canvas cleared.');
}
