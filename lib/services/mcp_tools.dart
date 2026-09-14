import 'dart:convert';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'app_version.dart';
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
    name: 'flowcraft_read',
    description:
        'Reads back every shape currently on the FlowCraft canvas, each with '
        'its id, type, geometry, text and colours — the same field names '
        'flowcraft_draw accepts. Call this before flowcraft_update or '
        'flowcraft_delete: those tools address elements by the id this '
        'returns, so you can correct one shape (move/resize/recolour/relabel '
        'or delete it) instead of clearing the board and redrawing '
        'everything.',
    inputSchema: _emptySchema,
    run: _runRead,
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
    name: 'flowcraft_update',
    description:
        'Updates existing shapes on the FlowCraft canvas in place, addressing '
        'each by the id from flowcraft_read. Only the fields you include '
        'change; everything else — position, size, colour, text — is left as '
        'it was, and every other element on the canvas is untouched. Use the '
        'same field names as flowcraft_draw (x/y/width/height for boxes, '
        'fromX/fromY/toX/toY for lines and arrows, text, fontSize, '
        'strokeColor, fillColor). You cannot change an element\'s type this '
        'way — delete it and draw a new one instead.',
    inputSchema: _updateSchema,
    run: _runUpdate,
  ),
  McpTool(
    name: 'flowcraft_delete',
    description:
        'Deletes specific shapes from the FlowCraft canvas by id (as returned '
        'by flowcraft_read), leaving every other element in place. Use this '
        'instead of flowcraft_clear when you want to remove a few elements '
        'rather than the whole board.',
    inputSchema: _deleteSchema,
    run: _runDelete,
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
  )
  run;

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

/// The per-element shape vocabulary, shared verbatim by `flowcraft_draw`
/// and `flowcraft_update` so reading, drawing and editing all speak the same
/// field names. `flowcraft_read` emits exactly these keys (plus `id`), which
/// is what lets an agent feed a read result straight back into an update.
const Map<String, Object?> _elementProperties = {
  'type': {
    'type': 'string',
    'description':
        'rectangle | ellipse | diamond | triangle | '
        'sticky | text | arrow | line',
  },
  'x': {'type': 'number', 'description': 'Left edge (bounded shapes/text).'},
  'y': {'type': 'number', 'description': 'Top edge (bounded shapes/text).'},
  'width': {'type': 'number', 'description': 'Box width (bounded shapes).'},
  'height': {'type': 'number', 'description': 'Box height (bounded shapes).'},
  'fromX': {'type': 'number', 'description': 'Start X (arrow/line).'},
  'fromY': {'type': 'number', 'description': 'Start Y (arrow/line).'},
  'toX': {'type': 'number', 'description': 'End X (arrow/line).'},
  'toY': {'type': 'number', 'description': 'End Y (arrow/line).'},
  'text': {
    'type': 'string',
    'maxLength': maxDiagramTextLength,
    'description':
        'Label text, if any. At most 4096 characters; '
        'split longer text across several elements.',
  },
  'fontSize': {'type': 'number', 'description': 'Label font size.'},
  'strokeColor': {
    'type': 'string',
    'description':
        'Hex color as "#RRGGBB" or "#AARRGGBB", e.g. '
        '"#1E1E1E". Defaults to black.',
  },
  'fillColor': {
    'type': 'string',
    'description':
        'Hex color as "#RRGGBB" or "#AARRGGBB", '
        'optional. No fill if omitted.',
  },
};

const Map<String, Object?> _drawSchema = {
  'type': 'object',
  'properties': {
    'mode': {
      'type': 'string',
      'description':
          '"add" appends to the existing canvas (default). '
          '"replace" clears the canvas first.',
    },
    'elements': {
      'type': 'array',
      'description': 'Shapes to draw, in canvas order (first = bottom).',
      'items': {
        'type': 'object',
        'properties': _elementProperties,
        'required': ['type'],
      },
    },
  },
  'required': ['elements'],
};

/// `flowcraft_update` takes the same per-element vocabulary, but keyed by the
/// element's `id` (from `flowcraft_read`) instead of a `type`: an update
/// names *which* element to change and then the fields to change on it.
const Map<String, Object?> _updateSchema = {
  'type': 'object',
  'properties': {
    'elements': {
      'type': 'array',
      'description':
          'Patches to apply, each naming an element by "id" and the fields to '
          'change. Omitted fields are left as they are.',
      'items': {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Id of the element to update, from flowcraft_read.',
          },
          ..._elementProperties,
        },
        'required': ['id'],
      },
    },
  },
  'required': ['elements'],
};

const Map<String, Object?> _deleteSchema = {
  'type': 'object',
  'properties': {
    'ids': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Ids of the elements to delete, as returned by flowcraft_read.',
    },
  },
  'required': ['ids'],
};

/// Reaching this handler at all proves the app is up — the server running
/// it *is* the app — so the interesting parts of the answer are which
/// build this is and how much is currently on the canvas.
McpToolResult _runStatus(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final count = controller.elements.length;
  return McpToolResult(
    'FlowCraft app (version $appVersion) is running and reachable. The '
    'canvas currently holds $count element(s).',
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

/// Serialises the whole canvas as JSON text so the model gets one parseable
/// blob rather than prose it has to scrape ids out of. Each element carries
/// its `id`, which is the handle `flowcraft_update`/`flowcraft_delete` then
/// address it by.
McpToolResult _runRead(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final described = describeDiagramElements(controller.elements);
  return McpToolResult(
    jsonEncode({'count': described.length, 'elements': described}),
  );
}

McpToolResult _runUpdate(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final raw = arguments['elements'];
  if (raw is! List || raw.isEmpty) {
    return const McpToolResult.failed(
      'No elements to update. Pass a non-empty "elements" array, each entry '
      'an object with an "id" from flowcraft_read.',
    );
  }

  final byId = {for (final e in controller.elements) e.id: e};
  final patched = <SketchElement>[];
  final missing = <String>[];
  for (final entry in raw) {
    if (entry is! Map) {
      return McpToolResult.failed(
        'Each element must be an object, got: $entry',
      );
    }
    final map = entry.cast<String, dynamic>();
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      return McpToolResult.failed(
        'Every element to update needs a non-empty string "id" (call '
        'flowcraft_read to get element ids).',
      );
    }
    final current = byId[id];
    if (current == null) {
      // A stale id is collected rather than fatal: the rest of the batch
      // still applies, and the model is told which ids to re-read.
      missing.add(id);
      continue;
    }
    try {
      patched.add(applyDiagramPatch(current, map));
    } on DiagramSpecException catch (e) {
      // Name the offending id so the model corrects that entry, not the
      // whole batch. `_callTool` would otherwise report a bare message.
      return McpToolResult.failed('Could not update element "$id": $e');
    }
  }

  if (patched.isEmpty) {
    // Nothing matched at all — a failure the model can act on (re-read for
    // current ids) rather than a silent success that changed nothing.
    return McpToolResult.failed(
      'None of the given ids are on the canvas'
      '${missing.isEmpty ? '' : ': ${missing.join(', ')}'}. '
      'Call flowcraft_read for the current element ids.',
    );
  }

  final updated = controller.updateAll(patched);
  final message = StringBuffer('Updated $updated element(s) on FlowCraft.');
  if (missing.isNotEmpty) {
    message.write(
      ' ${missing.length} id(s) were not on the canvas: ${missing.join(', ')}.',
    );
  }
  return McpToolResult(message.toString());
}

McpToolResult _runDelete(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  final raw = arguments['ids'];
  if (raw is! List || raw.isEmpty) {
    return const McpToolResult.failed(
      'No ids to delete. Pass a non-empty "ids" array of element ids (call '
      'flowcraft_read to get them).',
    );
  }

  final ids = <String>[];
  for (final entry in raw) {
    if (entry is! String || entry.isEmpty) {
      return McpToolResult.failed(
        'Every id must be a non-empty string, got: $entry',
      );
    }
    ids.add(entry);
  }

  final present = {for (final e in controller.elements) e.id};
  final missing = [
    for (final id in ids)
      if (!present.contains(id)) id,
  ];
  final removed = controller.removeIds(ids);
  final message = StringBuffer('Deleted $removed element(s) from FlowCraft.');
  if (missing.isNotEmpty) {
    message.write(
      ' ${missing.length} id(s) were not on the canvas: ${missing.join(', ')}.',
    );
  }
  return McpToolResult(message.toString());
}

McpToolResult _runClear(
  SketchController controller,
  Map<String, Object?> arguments,
) {
  controller.clear();
  return const McpToolResult('Canvas cleared.');
}
