import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flowcraft/core/domain/arrow_binding.dart';
import 'package:flowcraft/core/domain/frame_membership.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'app_version.dart';
import 'canvas_exporter.dart';
import 'diagram_layout.dart';
import 'diagram_spec.dart';
import 'export_file_sink.dart';
import 'image_source.dart';
import 'mcp_checkpoints.dart';
import 'mcp_guide.dart';
import 'mcp_host.dart';
import 'svg_exporter.dart';
import 'text_import/detect.dart';
import 'text_import/excalidraw.dart';
import 'text_import/dbml.dart';

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
        'everything. Large canvases: narrow with ids / types / frame / region, '
        'and page with limit and offset (the reply carries total and '
        'nextOffset). Image elements omit their bytes unless '
        'includeImageData is true.',
    inputSchema: _readSchema,
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
        'whether the app is reachable. For flowcharts, dependency graphs and '
        'anything else that is nodes plus edges, use flowcraft_diagram '
        'instead — it positions the boxes for you; for Mermaid, DBML or '
        'Excalidraw text use flowcraft_import. Also draws frames, icons, '
        'images and ER entities (see flowcraft_guide).',
    inputSchema: _drawSchema,
    run: _runDraw,
    mutates: true,
  ),
  McpTool(
    name: 'flowcraft_diagram',
    description:
        'Draws a graph on the FlowCraft canvas and lays it out '
        'automatically: give it nodes (id, label, optional shape/colours) '
        'and edges (from/to node ids) — no coordinates. Boxes are ranked, '
        'ordered to limit crossings and spaced evenly; arrows are bound to '
        'their boxes so they follow if a box is moved. Returns a map from '
        'your node ids to the element ids, usable with flowcraft_update and '
        'flowcraft_delete. Prefer this over flowcraft_draw for flowcharts, '
        'dependency graphs, state machines and architecture diagrams. Nodes '
        'with "attributes" become ER entities; "frames" group nodes.',
    inputSchema: _diagramSchema,
    run: _runDiagram,
    mutates: true,
  ),
  McpTool(
    name: 'flowcraft_import',
    description:
        'Imports a diagram written as text: Mermaid (flowchart / graph and '
        'erDiagram), DBML, an Excalidraw scene or a FlowCraft JSON scene. '
        'format "auto" (default) detects it. Mermaid and DBML are laid out '
        'for you like flowcraft_diagram (subgraphs become frames, ER '
        'relations get crow\'s-foot ends bound to the rows). A syntax error '
        'is reported with its line number and leaves the canvas untouched. '
        'mode "add" (default) places the result beside what is there; '
        '"replace" clears the canvas first. The reply lists the new ids and '
        'how many source elements were dropped as unsupported.',
    inputSchema: _importSchema,
    run: _runImport,
    mutates: true,
  ),
  McpTool(
    name: 'flowcraft_update',
    description:
        'Updates existing shapes on the FlowCraft canvas in place, addressing '
        'each by the id from flowcraft_read. Only the fields you include '
        'change; everything else — position, size, colour, text — is left as '
        'it was, and every other element on the canvas is untouched. Use the '
        'same field names as flowcraft_draw (x/y/width/height for boxes, '
        'fromX/fromY/toX/toY for lines and arrows, fromId/toId to attach or '
        'detach an arrow end, text, fontSize, '
        'strokeColor, fillColor). You cannot change an element\'s type this '
        'way — delete it and draw a new one instead.',
    inputSchema: _updateSchema,
    run: _runUpdate,
    mutates: true,
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
    mutates: true,
  ),
  McpTool(
    name: 'flowcraft_clear',
    description: 'Removes every shape from the FlowCraft canvas.',
    inputSchema: _emptySchema,
    run: _runClear,
    mutates: true,
  ),
  McpTool(
    name: 'flowcraft_screenshot',
    description:
        'Returns a PNG image of the canvas (or only the elements matching '
        'ids / types / frame / region) so you can look at what you drew and fix '
        'overlaps, clipped text or crossed arrows. Fails when nothing '
        'matches.',
    inputSchema: _screenshotSchema,
    run: _runScreenshot,
  ),
  McpTool(
    name: 'flowcraft_export',
    description:
        'Exports the canvas (or only the elements matching ids / types / '
        'frame / region) as png, svg or json. Without "path" the result '
        'comes back inline (png as an image, svg / json as text). With '
        '"path" it is written to disk: an absolute path (or ~/...) whose '
        'extension matches the format, in an existing folder; an existing '
        'file needs overwrite: true, and ~/.flowcraft is off limits. Fails '
        'when nothing matches.',
    inputSchema: _exportSchema,
    run: _runExport,
  ),
  McpTool(
    name: 'flowcraft_guide',
    description:
        'Returns the FlowCraft drawing guide: every tool, the element '
        'vocabulary, layout and colour conventions, and examples. Read it '
        'once before drawing.',
    inputSchema: _guideSchema,
    run: _runGuide,
  ),
  McpTool(
    name: 'flowcraft_checkpoint',
    description:
        'Canvas snapshots. A checkpoint is taken automatically before every '
        'tool that changes the canvas (the last 20 are kept, in memory). '
        'action "list" shows them, "create" takes one now (optional label), '
        '"restore" with an id brings that scene back; the restore is one '
        'undo step in the app. A checkpoint can only be restored in the '
        'project it was taken in.',
    inputSchema: _checkpointSchema,
    run: _runCheckpoint,
  ),
  McpTool(
    name: 'flowcraft_project',
    description:
        'Manages the saved whiteboards. action "list" shows them, "current" '
        'the open one, "open" switches to one by id or unique name, "create" '
        'starts a new empty one with a name, "rename" renames the project '
        'with the given id. "link" (id or name, plus an absolute "path") '
        'keeps a project mirrored to a scene file in a repo: an existing '
        'scene file is ADOPTED (the board is replaced by its contents, the '
        'file is left untouched), a missing file gets the current scene '
        'written to it, and any other file is refused. "unlink" stops the '
        'mirroring. Switching saves the outgoing project first.',
    inputSchema: _projectSchema,
    run: _runProject,
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
    this.mutates = false,
  });

  final String name;
  final String description;

  /// JSON Schema for `arguments`, sent verbatim in `tools/list`.
  final Map<String, Object?> inputSchema;

  /// May await (a screenshot rasterises), hence [FutureOr].
  final FutureOr<McpToolResult> Function(
    McpToolContext ctx,
    Map<String, Object?> arguments,
  )
  run;

  /// Whether a call changes the canvas. The handler snapshots the scene
  /// into [McpCheckpoints] before running such a tool, so a bad edit by an
  /// agent can be rolled back with `flowcraft_checkpoint`.
  final bool mutates;

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
  const McpToolResult(this.text) : isError = false, png = null;
  const McpToolResult.failed(this.text) : isError = true, png = null;

  /// A PNG image block, optionally followed by a caption.
  McpToolResult.image(Uint8List this.png, {String? text})
    : text = text ?? '',
      isError = false;

  final String text;
  final bool isError;
  final Uint8List? png;

  Map<String, Object?> toJson() => {
    'content': [
      if (png != null)
        {'type': 'image', 'data': base64Encode(png!), 'mimeType': 'image/png'},
      if (png == null || text.isNotEmpty) {'type': 'text', 'text': text},
    ],
    'isError': isError,
  };
}

/// What a tool handler works on: the live canvas, the checkpoint ring and
/// (null in tests that don't wire one) the saved-project library.
class McpToolContext {
  const McpToolContext({
    required this.controller,
    required this.checkpoints,
    this.projects,
  });

  final SketchController controller;
  final McpCheckpoints checkpoints;
  final McpProjectsHost? projects;
}

const Map<String, Object?> _emptySchema = {
  'type': 'object',
  'properties': <String, Object?>{},
};

/// [ArrowheadStyle] names for the schemas (a test keeps this in step).
const List<String> _arrowheadNames = [
  'none',
  'arrow',
  'one',
  'many',
  'zeroOrOne',
  'zeroOrMany',
  'oneOrMany',
];

/// The `iconCatalog` names for the schemas. `McpTool` declarations are
/// const, so this cannot be computed from the catalog; a test checks it
/// against `iconCatalog.keys` (the guide builds its list from the catalog).
const String iconNamesText =
    'database, server, cloud, user, queue, lock, api, storage, cache, '
    'function, web, mobile, mail, schedule, warning, key, file, folder, '
    'globe, gear, bug, chart, robot, terminal';

const Map<String, Object?> _attributeSchema = {
  'type': 'object',
  'properties': {
    'name': {
      'type': 'string',
      'description': 'Row name, unique in the entity.',
    },
    'type': {'type': 'string', 'description': 'Column type, e.g. int.'},
    'pk': {'type': 'boolean', 'description': 'Primary key (PK tag).'},
    'fk': {'type': 'boolean', 'description': 'Foreign key (FK tag).'},
  },
  'required': ['name'],
};

/// The per-element shape vocabulary, shared verbatim by `flowcraft_draw`
/// and `flowcraft_update` so reading, drawing and editing all speak the same
/// field names. `flowcraft_read` emits exactly these keys (plus `id`), which
/// is what lets an agent feed a read result straight back into an update.
const Map<String, Object?> _elementProperties = {
  'type': {
    'type': 'string',
    'description':
        'rectangle | ellipse | diamond | triangle | sticky | text | arrow | '
        'line | frame | icon | image | entity. frame: a named 1px container '
        '(x/y/width/height/name) that is drawn behind what it wraps; icon: '
        'a glyph (x/y/width/height/name); image: a picture (x/y + path or '
        'dataUrl); entity: an ER table (x/y/width/name/attributes), its '
        'height follows its rows.',
  },
  'name': {
    'type': 'string',
    'description':
        'frame: the label above its top-left corner. entity: the table name. '
        'icon: the glyph, one of $iconNamesText.',
  },
  'attributes': {
    'type': 'array',
    'description':
        'Entity rows, top to bottom. Row names are unique; an arrow binds to '
        'a row with fromAttribute / toAttribute.',
    'items': _attributeSchema,
  },
  'path': {
    'type': 'string',
    'description':
        'Image only: absolute file path (or ~/...) ending in .png, .jpg, '
        '.jpeg, .webp or .gif; at most 4 MiB. Use this or dataUrl.',
  },
  'dataUrl': {
    'type': 'string',
    'description':
        'Image only: "data:image/png;base64,..." (png, jpeg, webp or gif; at '
        'most 4 MiB decoded). Use this or path. Omit width and height to get '
        'the image\'s natural size; give one to keep the aspect ratio.',
  },
  'elbow': {
    'type': 'boolean',
    'description':
        'Arrows only: route with right-angle bends instead of a straight '
        'segment.',
  },
  'startHead': {
    'type': 'string',
    'enum': _arrowheadNames,
    'description':
        'Arrows only: glyph at the start. none (default), arrow, or an ER '
        'cardinality: one, many, zeroOrOne, zeroOrMany, oneOrMany.',
  },
  'endHead': {
    'type': 'string',
    'enum': _arrowheadNames,
    'description': 'Arrows only: glyph at the end. Default arrow.',
  },
  'fromAttribute': {
    'type': 'string',
    'description':
        'Arrows only: with fromId naming an entity, the row name the start '
        'attaches to (on the facing side, at that row). "" detaches.',
  },
  'toAttribute': {
    'type': 'string',
    'description':
        'Arrows only: with toId naming an entity, the row name the end '
        'attaches to. "" detaches.',
  },
  'fontFamily': {
    'type': 'string',
    'enum': ['sans', 'mono'],
    'description':
        'Label font: sans (Inter, default) or mono (JetBrains Mono).',
  },
  'bold': {'type': 'boolean', 'description': 'Bold label text.'},
  'align': {
    'type': 'string',
    'enum': ['left', 'center', 'right'],
    'description':
        'Text elements only (type "text"): horizontal alignment of its '
        'lines. Shape labels are always centred.',
  },
  'x': {'type': 'number', 'description': 'Left edge (bounded shapes/text).'},
  'y': {'type': 'number', 'description': 'Top edge (bounded shapes/text).'},
  'width': {'type': 'number', 'description': 'Box width (bounded shapes).'},
  'height': {'type': 'number', 'description': 'Box height (bounded shapes).'},
  'fromX': {'type': 'number', 'description': 'Start X (arrow/line).'},
  'fromY': {'type': 'number', 'description': 'Start Y (arrow/line).'},
  'toX': {'type': 'number', 'description': 'End X (arrow/line).'},
  'toY': {'type': 'number', 'description': 'End Y (arrow/line).'},
  'fromId': {
    'type': 'string',
    'description':
        'Arrows only: id of an existing rectangle/ellipse/diamond/triangle/'
        'sticky to attach the start to (ids come from flowcraft_read, a '
        'flowcraft_draw reply, or flowcraft_diagram\'s key map). The tip '
        'snaps to the shape\'s outline and follows it when the shape moves. '
        'Overrides fromX/fromY; "" detaches. Shapes in the same '
        'flowcraft_draw call cannot be referenced - use flowcraft_diagram '
        'for graphs.',
  },
  'toId': {
    'type': 'string',
    'description':
        'Arrows only: id of an existing shape to attach the end to; same '
        'rules as fromId. Overrides toX/toY; "" detaches.',
  },
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

/// Filters shared by every tool that works on "some of the canvas".
const Map<String, Object?> _selectionProperties = {
  'ids': {
    'type': 'array',
    'items': {'type': 'string'},
    'description': 'Only these element ids.',
  },
  'types': {
    'type': 'array',
    'items': {'type': 'string'},
    'description': 'Only these element types, e.g. ["rectangle", "arrow"].',
  },
  'frame': {
    'type': 'string',
    'description':
        'Only this frame (by id or case-insensitive name) and the elements '
        'wholly inside it. An unknown frame fails.',
  },
  'region': {
    'type': 'object',
    'description': 'Only elements whose bounds touch this canvas rectangle.',
    'properties': {
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'width': {'type': 'number'},
      'height': {'type': 'number'},
    },
    'required': ['x', 'y', 'width', 'height'],
  },
};

const Map<String, Object?> _readSchema = {
  'type': 'object',
  'properties': {
    ..._selectionProperties,
    'limit': {
      'type': 'integer',
      'description': 'Page size, 1-2000. Default 500.',
    },
    'offset': {
      'type': 'integer',
      'description': 'Elements to skip, for paging. Default 0.',
    },
    'includeImageData': {
      'type': 'boolean',
      'description':
          'Include the base64 bytes of image elements (up to 4 MiB each). '
          'Default false: images report mimeType, width, height and bytes.',
    },
  },
};

const Map<String, Object?> _exportSchema = {
  'type': 'object',
  'properties': {
    'format': {
      'type': 'string',
      'enum': ['png', 'svg', 'json'],
      'description':
          'png (raster), svg (vector) or json (a FlowCraft scene, '
          'importable with flowcraft_import).',
    },
    ..._selectionProperties,
    'path': {
      'type': 'string',
      'description':
          'Write to this file instead of returning inline: absolute (or '
          '~/...), extension .png / .svg / .json matching format, existing '
          'parent folder.',
    },
    'overwrite': {
      'type': 'boolean',
      'description': 'Replace an existing file at path. Default false.',
    },
    'pixelRatio': {
      'type': 'number',
      'description': 'png only: scale, 0.25-4. Default 2.',
    },
    'background': {
      'type': 'string',
      'description':
          'Hex "#RRGGBB" or "#AARRGGBB". Default white for png, none for '
          'svg.',
    },
  },
  'required': ['format'],
};

const Map<String, Object?> _importSchema = {
  'type': 'object',
  'properties': {
    'text': {
      'type': 'string',
      'description':
          'The diagram source: Mermaid ("flowchart LR\\n a --> b" or '
          '"erDiagram"), DBML ("Table users { id int [pk] }"), an '
          'Excalidraw scene JSON or a FlowCraft scene JSON.',
    },
    'format': {
      'type': 'string',
      'enum': ['auto', 'mermaid', 'dbml', 'excalidraw', 'json'],
      'description': 'Default auto: detected from the text.',
    },
    'mode': {
      'type': 'string',
      'enum': ['add', 'replace'],
      'description':
          '"add" (default) places the result beside existing content; '
          '"replace" clears the canvas first.',
    },
    'direction': {
      'type': 'string',
      'enum': ['TB', 'LR', 'BT', 'RL'],
      'description':
          'Mermaid / DBML layout direction; overrides the one in the text.',
    },
    'connectors': {
      'type': 'string',
      'enum': ['straight', 'elbow'],
      'description': 'Mermaid / DBML arrow routing. Default straight.',
    },
  },
  'required': ['text'],
};

const Map<String, Object?> _screenshotSchema = {
  'type': 'object',
  'properties': {
    ..._selectionProperties,
    'maxSide': {
      'type': 'integer',
      'description':
          'Longest side of the image in pixels, 64-8192. Default 1568. '
          'Smaller images are cheaper to look at.',
    },
  },
};

const Map<String, Object?> _guideSchema = {
  'type': 'object',
  'properties': {
    'topic': {
      'type': 'string',
      'enum': ['all', 'tools', 'vocabulary', 'layout', 'style', 'examples'],
      'description': 'Section to return. Default all.',
    },
  },
};

const Map<String, Object?> _checkpointSchema = {
  'type': 'object',
  'properties': {
    'action': {
      'type': 'string',
      'enum': ['list', 'create', 'restore'],
    },
    'id': {'type': 'string', 'description': 'Checkpoint id for restore.'},
    'label': {'type': 'string', 'description': 'Optional name for create.'},
  },
  'required': ['action'],
};

const Map<String, Object?> _projectSchema = {
  'type': 'object',
  'properties': {
    'action': {
      'type': 'string',
      'enum': ['list', 'current', 'open', 'create', 'rename', 'link', 'unlink'],
    },
    'id': {
      'type': 'string',
      'description': 'Project id (open by id, or the project to rename).',
    },
    'name': {
      'type': 'string',
      'description':
          'open / link / unlink: project name instead of id. create / rename: '
          'the new name.',
    },
    'path': {
      'type': 'string',
      'description': 'link: absolute path of the .flowcraft / .json file.',
    },
  },
  'required': ['action'],
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

const Map<String, Object?> _diagramSchema = {
  'type': 'object',
  'properties': {
    'nodes': {
      'type': 'array',
      'description': 'The boxes of the graph.',
      'items': {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Your own unique key; edges refer to it.',
          },
          'label': {
            'type': 'string',
            'description': 'Text inside the box (defaults to the id).',
          },
          'shape': {
            'type': 'string',
            'enum': ['rectangle', 'ellipse', 'diamond', 'triangle'],
            'description': 'Box shape. Default rectangle.',
          },
          'fillColor': {
            'type': 'string',
            'description': 'Hex fill, RRGGBB or AARRGGBB.',
          },
          'strokeColor': {
            'type': 'string',
            'description': 'Hex outline, RRGGBB or AARRGGBB.',
          },
          'attributes': {
            'type': 'array',
            'description':
                'Makes the node an ER entity (table) with these rows; its '
                'label is the table name.',
            'items': _attributeSchema,
          },
        },
        'required': ['id'],
      },
    },
    'edges': {
      'type': 'array',
      'description': 'Arrows between nodes, from -> to. No edge labels.',
      'items': {
        'type': 'object',
        'properties': {
          'from': {'type': 'string', 'description': 'Source node id.'},
          'to': {'type': 'string', 'description': 'Target node id.'},
          'strokeColor': {
            'type': 'string',
            'description': 'Hex arrow colour, RRGGBB or AARRGGBB.',
          },
          'fromCardinality': {
            'type': 'string',
            'enum': _arrowheadNames,
            'description': 'Glyph at the from end (ER: one, zeroOrMany, ...).',
          },
          'toCardinality': {
            'type': 'string',
            'enum': _arrowheadNames,
            'description': 'Glyph at the to end.',
          },
          'fromAttribute': {
            'type': 'string',
            'description': 'Entity row of the from node to attach to.',
          },
          'toAttribute': {
            'type': 'string',
            'description': 'Entity row of the to node to attach to.',
          },
        },
        'required': ['from', 'to'],
      },
    },
    'frames': {
      'type': 'array',
      'description':
          'Named containers drawn behind groups of nodes, each sized to '
          'wrap its members.',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Label of the frame.'},
          'members': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Node ids inside the frame.',
          },
        },
        'required': ['name', 'members'],
      },
    },
    'connectors': {
      'type': 'string',
      'enum': ['straight', 'elbow'],
      'description': 'Arrow routing. Default straight.',
    },
    'direction': {
      'type': 'string',
      'enum': ['TB', 'LR', 'BT', 'RL'],
      'description': 'Flow direction. Default TB (top to bottom).',
    },
    'mode': {
      'type': 'string',
      'enum': ['add', 'replace'],
      'description':
          '"add" (default) places the graph to the right of existing '
          'content; "replace" clears the canvas first.',
    },
  },
  'required': ['nodes'],
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
McpToolResult _runStatus(McpToolContext ctx, Map<String, Object?> arguments) {
  final controller = ctx.controller;
  final count = controller.elements.length;
  return McpToolResult(
    'FlowCraft app (version $appVersion) is running and reachable. The '
    'canvas currently holds $count element(s).',
  );
}

Future<McpToolResult> _runDraw(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) async {
  final controller = ctx.controller;
  final raw = arguments['elements'];
  if (raw is! List || raw.isEmpty) {
    return const McpToolResult.failed('No elements provided.');
  }
  // Anything that isn't the literal "replace" appends, matching the
  // bridge's behaviour — an unrecognized mode must never wipe the canvas.
  final mode = arguments['mode'] == 'replace' ? 'replace' : 'add';

  // Images may name a file or a data URL; the parser itself is synchronous,
  // so they are turned into bytes first.
  final resolved = await ImageSource.resolve(raw);
  // Replace wipes the canvas, so nothing on it can be bound to.
  final elements = parseDiagramElements(
    resolved,
    bindableIds: mode == 'replace' ? const {} : _bindableIds(controller),
    entities: mode == 'replace' ? const {} : _entities(controller),
  );
  if (mode == 'replace') {
    controller.replaceAll(elements);
  } else {
    controller.addAll(elements);
  }
  _show(controller, elements);
  return McpToolResult(
    'Drew ${elements.length} element(s) on FlowCraft (mode: $mode). '
    'Canvas now has ${controller.elements.length} element(s) total. '
    'Element ids, in order: ${elements.map((e) => e.id).join(', ')}.',
  );
}

/// Ids of the elements an arrow may currently attach to.
Set<String> _bindableIds(SketchController controller) => {
  for (final e in controller.elements)
    if (ArrowBinding.isBindable(e)) e.id,
};

/// The canvas's entities by id, so an arrow's row names can be checked.
Map<String, SketchEntity> _entities(SketchController controller) => {
  for (final e in controller.elements)
    if (e is SketchEntity) e.id: e,
};

/// Brings freshly added [elements] into view, then plays their draw-on.
void _show(SketchController controller, List<SketchElement> elements) {
  if (elements.isEmpty) return;
  controller.requestFrame(
    CanvasExporter.contentBounds(elements),
    onlyIfHidden: true,
  );
  controller.requestReveal([for (final e in elements) e.id]);
}

/// Where a new graph goes: the origin in replace mode or on an empty
/// canvas, otherwise beside what is already there.
Offset _graphOrigin(SketchController controller, bool replace) {
  if (replace || controller.elements.isEmpty) return Offset.zero;
  final existing = CanvasExporter.contentBounds(controller.elements);
  return Offset(existing.right + 96, existing.top);
}

/// Lays out a node/edge graph and puts it on the canvas; shared by
/// `flowcraft_diagram` and the Mermaid / DBML branches of `flowcraft_import`.
({List<SketchElement> elements, Map<String, String> nodeIds}) _placeGraph(
  SketchController controller,
  Map<String, Object?> graph, {
  required bool replace,
}) {
  final nodes = graph['nodes'];
  final edges = graph['edges'] ?? const [];
  final frames = graph['frames'] ?? const [];
  if (nodes is! List || edges is! List || frames is! List) {
    throw DiagramSpecException('"nodes", "edges" and "frames" must be lists.');
  }
  final built = buildDiagram(
    nodes: nodes,
    edges: edges,
    frames: frames,
    direction: _stringArg(graph, 'direction') ?? 'TB',
    connectors: _stringArg(graph, 'connectors') ?? 'straight',
    origin: _graphOrigin(controller, replace),
  );
  if (replace) {
    controller.replaceAll(built.elements);
  } else {
    controller.addAll(built.elements);
  }
  _show(controller, built.elements);
  return built;
}

Map<String, Object?> _boundsJson(List<SketchElement> elements) {
  final b = CanvasExporter.contentBounds(elements);
  return {'x': b.left, 'y': b.top, 'width': b.width, 'height': b.height};
}

McpToolResult _runDiagram(McpToolContext ctx, Map<String, Object?> arguments) {
  final built = _placeGraph(
    ctx.controller,
    arguments,
    replace: arguments['mode'] == 'replace',
  );
  return McpToolResult(
    jsonEncode({
      'nodes': built.nodeIds,
      'edges': [
        for (final e in built.elements)
          if (e is SketchArrow) e.id,
      ],
      'frames': [
        for (final e in built.elements)
          if (e is SketchFrame) e.id,
      ],
      'count': built.elements.length,
      'bounds': _boundsJson(built.elements),
    }),
  );
}

/// Serialises (a page of) the canvas as JSON text so the model gets one
/// parseable blob rather than prose it has to scrape ids out of. Each element
/// carries its `id`, which is the handle `flowcraft_update`/`flowcraft_delete`
/// then address it by. `count` is the size of this page; `total` is how many
/// elements matched the filters.
McpToolResult _runRead(McpToolContext ctx, Map<String, Object?> arguments) {
  final selected = selectElements(ctx.controller, arguments);
  final limit = _intArg(arguments, 'limit', 500, 1, 2000);
  final offset = _intArg(arguments, 'offset', 0, 0, 1 << 30);
  final page = selected.skip(offset).take(limit).toList();
  final next = offset + page.length;
  final described = describeDiagramElements(page);
  // A 4 MiB base64 blob must never land in a model's context by accident.
  if (arguments['includeImageData'] != true) {
    for (var i = 0; i < page.length; i++) {
      final el = page[i];
      if (el is SketchImage) {
        described[i]
          ..remove('data')
          ..['bytes'] = el.bytes.length;
      }
    }
  }
  return McpToolResult(
    jsonEncode({
      'count': page.length,
      'total': selected.length,
      'offset': offset,
      'limit': limit,
      if (next < selected.length) 'nextOffset': next,
      'elements': described,
    }),
  );
}

McpToolResult _runUpdate(McpToolContext ctx, Map<String, Object?> arguments) {
  final controller = ctx.controller;
  final raw = arguments['elements'];
  if (raw is! List || raw.isEmpty) {
    return const McpToolResult.failed(
      'No elements to update. Pass a non-empty "elements" array, each entry '
      'an object with an "id" from flowcraft_read.',
    );
  }

  final byId = {for (final e in controller.elements) e.id: e};
  final bindable = _bindableIds(controller);
  final entities = _entities(controller);
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
      patched.add(
        applyDiagramPatch(
          current,
          map,
          bindableIds: bindable,
          entities: entities,
        ),
      );
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

McpToolResult _runDelete(McpToolContext ctx, Map<String, Object?> arguments) {
  final controller = ctx.controller;
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

McpToolResult _runClear(McpToolContext ctx, Map<String, Object?> arguments) {
  final controller = ctx.controller;
  controller.clear();
  return const McpToolResult('Canvas cleared.');
}

// ── Selection & argument validation ─────────────────────────────────────

/// Elements matching `ids`, `types`, `frame` and `region` in [args], in
/// stacking order. Absent filters match everything. `frame` is a frame's id
/// or case-insensitive name and keeps the frame plus the elements wholly
/// inside it; a frame that does not exist throws. Shared by read, screenshot
/// and export so "the same selection" means the same thing everywhere.
List<SketchElement> selectElements(
  SketchController controller,
  Map<String, Object?> args,
) {
  final ids = _stringSet(args, 'ids');
  final types = _stringSet(args, 'types');
  final region = _region(args['region']);
  final inFrame = _frameSelection(controller, _stringArg(args, 'frame'));
  return [
    for (final e in controller.elements)
      if ((ids == null || ids.contains(e.id)) &&
          (inFrame == null || inFrame.contains(e.id)) &&
          (types == null || types.contains(e.toJson()['type'])) &&
          (region == null || _touches(e.bounds, region)))
        e,
  ];
}

/// Ids of the frame named [key] and its members; null when [key] is null.
Set<String>? _frameSelection(SketchController controller, String? key) {
  if (key == null) return null;
  final frames = controller.elements.whereType<SketchFrame>();
  final byId = frames.where((f) => f.id == key).toList();
  final hits = byId.isNotEmpty
      ? byId
      : frames.where((f) => f.name.toLowerCase() == key.toLowerCase()).toList();
  if (hits.isEmpty) {
    throw DiagramSpecException(
      frames.isEmpty
          ? 'No frame "$key": the canvas has no frames.'
          : 'No frame "$key". Frames on the canvas: '
                '${frames.map((f) => '"${f.name}" (${f.id})').join(', ')}.',
    );
  }
  return {
    for (final f in hits) ...[
      f.id,
      for (final m in FrameMembership.members(f, controller.elements)) m.id,
    ],
  };
}

/// Closed-interval overlap: [Rect.overlaps] ignores zero-area bounds (a
/// horizontal line), which a region should still catch.
bool _touches(Rect a, Rect b) =>
    a.left <= b.right &&
    b.left <= a.right &&
    a.top <= b.bottom &&
    b.top <= a.bottom;

Set<String>? _stringSet(Map<String, Object?> args, String key) {
  final raw = args[key];
  if (raw == null) return null;
  if (raw is! List || raw.any((e) => e is! String)) {
    throw DiagramSpecException('"$key" must be an array of strings.');
  }
  return raw.cast<String>().toSet();
}

Rect? _region(Object? raw) {
  if (raw == null) return null;
  double side(String key) {
    final v = raw is Map ? raw[key] : null;
    if (v is! num || !v.isFinite) {
      throw DiagramSpecException(
        '"region" must be an object with finite numbers x, y, width, height.',
      );
    }
    return v.toDouble();
  }

  final rect = Rect.fromLTWH(
    side('x'),
    side('y'),
    side('width'),
    side('height'),
  );
  if (rect.width < 0 || rect.height < 0) {
    throw DiagramSpecException('"region" width and height cannot be negative.');
  }
  return rect;
}

int _intArg(
  Map<String, Object?> args,
  String key,
  int fallback,
  int lo,
  int hi,
) {
  final raw = args[key];
  if (raw == null) return fallback;
  if (raw is! num || raw != raw.truncate() || raw < lo || raw > hi) {
    throw DiagramSpecException('"$key" must be an integer from $lo to $hi.');
  }
  return raw.toInt();
}

String? _stringArg(Map<String, Object?> args, String key) {
  final raw = args[key];
  if (raw == null) return null;
  if (raw is! String) throw DiagramSpecException('"$key" must be a string.');
  return raw;
}

// ── screenshot / guide ──────────────────────────────────────────────────

/// A reply bigger than this is wasted on a model (and some clients refuse
/// it), so the render is retried at half resolution.
const int _maxScreenshotBytes = 4 * 1024 * 1024;

Future<McpToolResult> _runScreenshot(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) async {
  final selected = selectElements(ctx.controller, arguments);
  if (selected.isEmpty) {
    return const McpToolResult.failed(
      'Nothing to capture: no element matches (or the canvas is empty).',
    );
  }
  final maxSide = _intArg(arguments, 'maxSide', 1568, 64, 8192);
  final region = _region(arguments['region']);
  final frame = region ?? CanvasExporter.contentBounds(selected).inflate(32);
  var ratio = math.min(
    2.0,
    maxSide / math.max(1.0, math.max(frame.width, frame.height)),
  );
  Uint8List png;
  var attempt = 0;
  do {
    png = await CanvasExporter.renderPng(
      selected,
      background: const Color(0xFFFFFFFF),
      pixelRatio: ratio,
      bounds: region,
    );
    ratio /= 2;
  } while (png.length > _maxScreenshotBytes && ++attempt <= 2);
  if (png.length > _maxScreenshotBytes) {
    return const McpToolResult.failed(
      'The screenshot is too large even at reduced size; pass a smaller '
      'region or maxSide.',
    );
  }
  // IHDR: big-endian width and height at byte 16.
  final header = ByteData.sublistView(png, 16, 24);
  return McpToolResult.image(
    png,
    text:
        '${header.getUint32(0)}x${header.getUint32(4)} px, '
        '${selected.length} element(s).',
  );
}

// ── import / export ─────────────────────────────────────────────────────

const int _maxImportChars = 8 * 1024 * 1024;

Future<McpToolResult> _runImport(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) async {
  final controller = ctx.controller;
  final text = _stringArg(arguments, 'text');
  if (text == null || text.trim().isEmpty) {
    return const McpToolResult.failed('import needs a non-empty "text".');
  }
  if (text.length > _maxImportChars) {
    return const McpToolResult.failed('"text" is larger than 8 MiB.');
  }
  final replace = arguments['mode'] == 'replace';
  final requested = _stringArg(arguments, 'format') ?? 'auto';
  final format = switch (requested) {
    'auto' => switch (detectTextFormat(text)) {
      TextFormat.json => 'json',
      TextFormat.excalidraw => 'excalidraw',
      TextFormat.mermaid => 'mermaid',
      TextFormat.dbml => 'dbml',
      TextFormat.unknown => null,
    },
    'mermaid' || 'dbml' || 'excalidraw' || 'json' => requested,
    _ => throw DiagramSpecException(
      'Unknown format "$requested". Use auto, mermaid, dbml, excalidraw or '
      'json.',
    ),
  };
  if (format == null) {
    return const McpToolResult.failed(
      'Could not tell what format this is. Mermaid starts with "flowchart", '
      '"graph" or "erDiagram"; DBML with "Table"; or pass "format" '
      'explicitly.',
    );
  }

  if (format == 'mermaid' || format == 'dbml') {
    // Parsing happens before anything touches the canvas, so a bad line
    // (reported with its number) leaves it as it was.
    final graph = <String, Object?>{
      ...(format == 'mermaid' ? parseMermaid(text) : parseDbml(text)),
      if (arguments['direction'] != null) 'direction': arguments['direction'],
      if (arguments['connectors'] != null)
        'connectors': arguments['connectors'],
    };
    final built = _placeGraph(controller, graph, replace: replace);
    return McpToolResult(
      jsonEncode({
        'format': format,
        'count': built.elements.length,
        'nodes': built.nodeIds,
        'dropped': 0,
      }),
    );
  }

  final List<SketchElement> parsed;
  final int dropped;
  if (format == 'excalidraw') {
    final r = parseExcalidraw(text);
    parsed = r.elements;
    dropped = r.dropped;
  } else {
    final load = SketchSerializer.loadJson(text);
    parsed = load.elements;
    dropped = load.droppedCount;
  }
  if (parsed.length > maxDiagramElements) {
    return McpToolResult.failed(
      'Too many elements: ${parsed.length}. At most $maxDiagramElements can '
      'be imported at once.',
    );
  }
  if (parsed.isEmpty) {
    return McpToolResult.failed(
      dropped == 0
          ? 'That $format scene holds no elements.'
          : 'None of its $dropped element(s) could be imported.',
    );
  }
  var incoming = _uniqueIds(parsed);
  if (!replace && controller.elements.isNotEmpty) {
    // Below the existing content, left-aligned with it.
    final existing = CanvasExporter.contentBounds(controller.elements);
    final fresh = CanvasExporter.contentBounds(incoming);
    final shift = Offset(
      existing.left - fresh.left,
      existing.bottom + 96 - fresh.top,
    );
    incoming = [for (final e in incoming) e.translate(shift)];
  }
  if (replace) {
    controller.replaceAll(incoming);
  } else {
    // A FlowCraft scene exported from this board carries ids already in use.
    // pasteElements re-ids the batch and remaps arrow bindings with it.
    final taken = {for (final e in controller.elements) e.id};
    if (incoming.any((e) => taken.contains(e.id))) {
      controller.pasteElements(incoming, offset: Offset.zero);
      incoming = controller.elements.sublist(
        controller.elements.length - incoming.length,
      );
    } else {
      controller.addAll(incoming);
    }
  }
  _show(controller, incoming);
  return McpToolResult(
    jsonEncode({
      'format': format,
      'count': incoming.length,
      'ids': [for (final e in incoming) e.id],
      'dropped': dropped,
    }),
  );
}

/// [els] with later duplicates of an id re-minted (the first keeps it), since
/// a hand-edited or merged file can repeat ids and `replaceAll` takes them
/// as-is. Bindings keep naming the first holder of an id.
List<SketchElement> _uniqueIds(List<SketchElement> els) {
  final seen = <String>{};
  return [
    for (final e in els)
      seen.add(e.id) ? e : e.withId(IdGenerator.generate('sketch')),
  ];
}

Future<McpToolResult> _runExport(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) async {
  final format = _stringArg(arguments, 'format');
  if (format != 'png' && format != 'svg' && format != 'json') {
    return const McpToolResult.failed('format must be png, svg or json.');
  }
  final selected = selectElements(ctx.controller, arguments);
  if (selected.isEmpty) {
    return const McpToolResult.failed(
      'Nothing to export: no element matches (or the canvas is empty).',
    );
  }
  final path = _stringArg(arguments, 'path');
  final overwrite = arguments['overwrite'] == true;
  if (path != null && !path.toLowerCase().endsWith('.$format')) {
    return McpToolResult.failed(
      'path must end in .$format for format $format.',
    );
  }
  final ratio = arguments['pixelRatio'] ?? 2;
  if (ratio is! num || !(ratio >= 0.25 && ratio <= 4)) {
    return const McpToolResult.failed('"pixelRatio" must be from 0.25 to 4.');
  }
  final background = _colorArg(arguments, 'background');

  final List<int> bytes;
  switch (format) {
    case 'png':
      bytes = await CanvasExporter.renderPng(
        selected,
        background: background ?? const Color(0xFFFFFFFF),
        pixelRatio: ratio.toDouble(),
        bounds: _region(arguments['region']),
      );
    case 'svg':
      bytes = utf8.encode(
        await SvgExporter.render(selected, background: background),
      );
    default:
      bytes = utf8.encode(SketchSerializer.serialize(selected));
  }

  if (path == null) {
    if (format == 'png') {
      return McpToolResult.image(
        Uint8List.fromList(bytes),
        text: '${selected.length} element(s), ${bytes.length} bytes.',
      );
    }
    return McpToolResult(utf8.decode(bytes));
  }
  try {
    final written = await ExportFileSink.writeTo(
      path,
      bytes,
      overwrite: overwrite,
      // The default protected folder is ~/.flowcraft (projects + token).
    );
    return McpToolResult(
      jsonEncode({'path': written, 'bytes': bytes.length, 'format': format}),
    );
  } on ExportPathException catch (e) {
    return McpToolResult.failed(e.message);
  }
}

/// A `#RRGGBB` / `#AARRGGBB` argument, null when absent.
Color? _colorArg(Map<String, Object?> args, String key) {
  final raw = _stringArg(args, key);
  if (raw == null) return null;
  final hex = raw.startsWith('#') ? raw.substring(1) : raw;
  final value = RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)
      ? int.parse(hex, radix: 16)
      : null;
  if (value == null) {
    throw DiagramSpecException('"$key" must be "#RRGGBB" or "#AARRGGBB".');
  }
  return Color(hex.length == 6 ? 0xFF000000 | value : value);
}

McpToolResult _runGuide(McpToolContext ctx, Map<String, Object?> arguments) {
  final topic = _stringArg(arguments, 'topic') ?? 'all';
  if (topic == 'all') return McpToolResult(mcpGuideText);
  final section = mcpGuideSections[topic];
  if (section == null) {
    return McpToolResult.failed(
      'Unknown topic "$topic". Use all, ${mcpGuideSections.keys.join(', ')}.',
    );
  }
  return McpToolResult(section);
}

// ── checkpoints ─────────────────────────────────────────────────────────

McpToolResult _runCheckpoint(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) {
  final projectId = ctx.projects?.activeId();
  final checkpoints = ctx.checkpoints;
  switch (_stringArg(arguments, 'action')) {
    case 'list':
      return McpToolResult(
        jsonEncode({
          'checkpoints': [
            for (final c in checkpoints.list())
              {
                'id': c.id,
                'cause': c.cause,
                'createdAt': c.createdAt.toUtc().toIso8601String(),
                'elementCount': c.elements.length,
                'restorable': c.projectId == projectId,
              },
          ],
        }),
      );
    case 'create':
      // ponytail: an unchanged scene reuses the previous checkpoint (and its
      // cause), so a label is dropped then; add a rename if that matters.
      final c = checkpoints.capture(
        ctx.controller,
        _stringArg(arguments, 'label') ?? 'manual',
        projectId,
      );
      return McpToolResult(jsonEncode({'id': c.id}));
    case 'restore':
      final id = _stringArg(arguments, 'id');
      if (id == null || id.isEmpty) {
        return const McpToolResult.failed('restore needs a checkpoint "id".');
      }
      final target = checkpoints.find(id);
      if (target == null) {
        return McpToolResult.failed(
          'No checkpoint "$id" (call action "list" for the current ones).',
        );
      }
      if (target.projectId != projectId) {
        return McpToolResult.failed(
          'Checkpoint "$id" belongs to another project; open that project '
          'to restore it.',
        );
      }
      checkpoints.capture(ctx.controller, 'restore', projectId);
      // History-tracked on purpose: Ctrl+Z in the app undoes the restore.
      ctx.controller.replaceAll(target.elements);
      return McpToolResult(
        'Restored $id (${target.elements.length} element(s)).',
      );
    default:
      return const McpToolResult.failed(
        'action must be "list", "create" or "restore".',
      );
  }
}

// ── projects ────────────────────────────────────────────────────────────

Future<McpToolResult> _runProject(
  McpToolContext ctx,
  Map<String, Object?> arguments,
) async {
  final host = ctx.projects;
  if (host == null) {
    return const McpToolResult.failed(
      'Project management is unavailable in this session.',
    );
  }
  final action = _stringArg(arguments, 'action');
  final name = _stringArg(arguments, 'name')?.trim();
  switch (action) {
    case 'list':
      final active = host.activeId();
      return McpToolResult(
        jsonEncode({
          'projects': [
            for (final p in host.list())
              {
                'id': p.id,
                'name': p.name,
                'elementCount': p.elementCount,
                'updatedAt': p.updatedAt.toUtc().toIso8601String(),
                'active': p.id == active,
                if (p.isBroken) 'broken': true,
              },
          ],
        }),
      );
    case 'current':
      final active = host.activeId();
      final project = _projectById(host, active);
      if (project == null) {
        return const McpToolResult.failed('No project is open.');
      }
      return McpToolResult(
        jsonEncode({
          'id': project.id,
          'name': project.name,
          'elementCount': ctx.controller.elements.length,
        }),
      );
    case 'open':
      final id = _stringArg(arguments, 'id');
      final matches = [
        for (final p in host.list())
          if (id != null
              ? p.id == id
              : name != null && p.name.toLowerCase() == name.toLowerCase())
            p,
      ];
      if (id == null && name == null) {
        return const McpToolResult.failed('open needs an "id" or a "name".');
      }
      if (matches.isEmpty) {
        return McpToolResult.failed(
          'No project matches "${id ?? name}" (call action "list").',
        );
      }
      if (matches.length > 1) {
        return McpToolResult.failed(
          'Several projects are named "$name"; open one by id: '
          '${matches.map((p) => p.id).join(', ')}.',
        );
      }
      final target = matches.single;
      if (target.isBroken) {
        return McpToolResult.failed('Project "${target.id}" is unreadable.');
      }
      await host.open(target.id);
      if (host.activeId() != target.id) {
        return McpToolResult.failed(
          'Could not open "${target.name}"; see the app for the reason.',
        );
      }
      _frameContent(ctx.controller);
      return McpToolResult(
        'Opened "${target.name}" (${ctx.controller.elements.length} '
        'element(s)).',
      );
    case 'create':
      if (name == null || name.isEmpty || name.length > 200) {
        return const McpToolResult.failed(
          'create needs a non-empty "name" of at most 200 characters.',
        );
      }
      final before = host.activeId();
      await host.create(name);
      final created = host.activeId();
      if (created == null || created == before) {
        return const McpToolResult.failed(
          'Could not create the project; see the app for the reason.',
        );
      }
      _frameContent(ctx.controller);
      return McpToolResult(jsonEncode({'id': created, 'name': name}));
    case 'rename':
      final id = _stringArg(arguments, 'id');
      if (id == null || _projectById(host, id) == null) {
        return McpToolResult.failed('rename needs the "id" of a project.');
      }
      if (name == null || name.isEmpty || name.length > 200) {
        return const McpToolResult.failed(
          'rename needs a non-empty new "name" of at most 200 characters.',
        );
      }
      await host.rename(id, name);
      if (_projectById(host, id)?.name != name) {
        return const McpToolResult.failed(
          'Could not rename the project; see the app for the reason.',
        );
      }
      return McpToolResult('Renamed to "$name".');
    case 'link':
    case 'unlink':
      final id = _stringArg(arguments, 'id');
      final path = _stringArg(arguments, 'path');
      final matches = [
        for (final p in host.list())
          if (id != null
              ? p.id == id
              : name != null && p.name.toLowerCase() == name.toLowerCase())
            p,
      ];
      if (matches.length != 1) {
        return McpToolResult.failed(
          '$action needs the "id" (or a unique "name") of one project.',
        );
      }
      final target = matches.single;
      if (action == 'unlink') {
        await host.unlink(target.id);
        return McpToolResult('Unlinked "${target.name}".');
      }
      if (path == null || path.isEmpty) {
        return const McpToolResult.failed('link needs a "path".');
      }
      try {
        await host.link(target.id, path);
      } on StateError catch (e) {
        return McpToolResult.failed(e.message);
      }
      _frameContent(ctx.controller);
      return McpToolResult('Linked "${target.name}" to $path.');
    default:
      return const McpToolResult.failed(
        'action must be list, current, open, create, rename, link or unlink.',
      );
  }
}

FlowProject? _projectById(McpProjectsHost host, String? id) {
  for (final p in host.list()) {
    if (p.id == id) return p;
  }
  return null;
}

/// Brings a freshly opened project's content on screen (nothing to frame on
/// an empty canvas).
void _frameContent(SketchController controller) {
  if (controller.elements.isEmpty) return;
  controller.requestFrame(CanvasExporter.contentBounds(controller.elements));
}
