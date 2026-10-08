import 'dart:math' as math;
import 'dart:ui';

import 'package:flowcraft/core/domain/graph_layout.dart';
import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/models/sketch_element.dart';

import 'diagram_spec.dart';

const double _fontSize = 16;
const _directions = {
  'TB': LayoutDirection.tb,
  'LR': LayoutDirection.lr,
  'BT': LayoutDirection.bt,
  'RL': LayoutDirection.rl,
};

/// Box size for a [label] in [shape]: text plus padding, floored at
/// 120x56, then widened because ellipses and diamonds/triangles have less
/// usable area inside the same bounding box.
Size _nodeSize(String label, String shape) {
  final text = TextMetrics.measure(text: label, fontSize: _fontSize);
  final w = math.max(120.0, text.width + 48);
  final h = math.max(56.0, text.height + 32);
  final scale = switch (shape) {
    'ellipse' => math.sqrt2,
    'diamond' || 'triangle' => 2.0,
    _ => 1.0,
  };
  return Size(w * scale, h * scale);
}

/// Padding a diagram frame keeps around the members it wraps.
const double _framePadding = 24;

/// Entity node width: wide enough for its widest "name  type" row.
double _entityWidth(SketchEntity e) {
  var widest = TextMetrics.measure(
    text: e.name,
    fontSize: e.fontSize,
    fontWeight: FontWeight.w700,
  ).width;
  for (final a in e.attributes) {
    final w = TextMetrics.measure(
      text: '${a.name}    ${a.type}',
      fontSize: e.fontSize,
    ).width;
    // ponytail: +56 covers the PK/FK tag column and padding, not measured.
    widest = math.max(widest, w + 56);
  }
  return math.max(e.rect.width, widest + 24);
}

/// Turns the `flowcraft_diagram` input into laid-out node elements plus
/// arrows bound to them. [nodeIds] maps each caller-chosen node key to the
/// element id minted for it.
///
/// This is the trust boundary for the tool, so everything is validated
/// before a single element exists; any problem throws
/// [DiagramSpecException] and the caller's canvas stays untouched.
({List<SketchElement> elements, Map<String, String> nodeIds}) buildDiagram({
  required List<dynamic> nodes,
  required List<dynamic> edges,
  String direction = 'TB',
  Offset origin = Offset.zero,
  String connectors = 'straight',
  List<dynamic> frames = const [],
}) {
  if (connectors != 'straight' && connectors != 'elbow') {
    throw DiagramSpecException(
      'Unknown connectors "$connectors". Use straight or elbow.',
    );
  }
  final dir = _directions[direction];
  if (dir == null) {
    throw DiagramSpecException(
      'Unknown direction "$direction". Use one of TB, LR, BT, RL.',
    );
  }
  if (nodes.isEmpty) {
    throw DiagramSpecException('"nodes" must be a non-empty list.');
  }
  if (nodes.length + edges.length + frames.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${nodes.length + edges.length + frames.length}. At most '
      '$maxDiagramElements nodes and edges fit in one call.',
    );
  }

  final keys = <String>[];
  final labels = <String, String>{};
  final shapes = <String, String>{};
  final nodeMaps = <String, Map<dynamic, dynamic>>{};
  for (final node in nodes) {
    if (node is! Map) {
      throw DiagramSpecException('Node must be an object, got: $node');
    }
    final id = node['id'];
    if (id is! String || id.isEmpty) {
      throw DiagramSpecException('Every node needs a non-empty string "id".');
    }
    if (nodeMaps.containsKey(id)) {
      throw DiagramSpecException('Duplicate node id "$id".');
    }
    final label = node['label'] ?? id;
    if (label is! String) {
      throw DiagramSpecException('Node "$id": "label" must be a string.');
    }
    if (label.length > maxDiagramTextLength) {
      throw DiagramSpecException(
        'Node "$id": "label" is too long: ${label.length} characters (max '
        '$maxDiagramTextLength).',
      );
    }
    final shape =
        node['shape'] ?? (node['attributes'] != null ? 'entity' : 'rectangle');
    if (!const {
      'rectangle',
      'ellipse',
      'diamond',
      'triangle',
      'entity',
    }.contains(shape)) {
      throw DiagramSpecException(
        'Node "$id": unknown shape "$shape". Use rectangle, ellipse, '
        'diamond, triangle or entity.',
      );
    }
    if (node['attributes'] != null && shape != 'entity') {
      throw DiagramSpecException(
        'Node "$id": "attributes" only applies to shape "entity".',
      );
    }
    keys.add(id);
    labels[id] = label;
    shapes[id] = shape as String;
    nodeMaps[id] = node;
  }

  final pairs = <(String, String)>[];
  final edgeMaps = <Map<dynamic, dynamic>>[];
  for (final edge in edges) {
    if (edge is! Map) {
      throw DiagramSpecException('Edge must be an object, got: $edge');
    }
    final from = edge['from'], to = edge['to'];
    for (final end in [from, to]) {
      if (end is! String || !nodeMaps.containsKey(end)) {
        throw DiagramSpecException(
          'Edge endpoint "$end" does not name a node id.',
        );
      }
    }
    if (from == to) {
      throw DiagramSpecException('Edge "$from" -> "$to" is a self-loop.');
    }
    pairs.add((from as String, to as String));
    edgeMaps.add(edge);
  }

  // Entity nodes are built up front: their height comes from their rows, and
  // layout needs the sizes before anything is placed.
  final entities = <String, SketchEntity>{};
  for (final k in keys) {
    if (shapes[k] != 'entity') continue;
    final probe =
        parseDiagramElements([
              {
                'type': 'entity',
                'name': labels[k],
                'attributes': nodeMaps[k]!['attributes'],
                'fontSize': SketchEntity.defaultFontSize,
                'fillColor': nodeMaps[k]!['fillColor'],
                'strokeColor': nodeMaps[k]!['strokeColor'],
              },
            ]).single
            as SketchEntity;
    entities[k] = probe.copyWith(
      rect: Rect.fromLTWH(0, 0, _entityWidth(probe), probe.rect.height),
    );
  }
  for (var i = 0; i < pairs.length; i++) {
    final edge = edgeMaps[i];
    final (from, to) = pairs[i];
    for (final key in const ['fromCardinality', 'toCardinality']) {
      _cardinality(edge, key, from, to);
    }
    for (final (attrKey, node) in [
      ('fromAttribute', from),
      ('toAttribute', to),
    ]) {
      final attr = edge[attrKey];
      if (attr == null) continue;
      final entity = entities[node];
      if (attr is! String ||
          entity == null ||
          !entity.attributes.any((a) => a.name == attr)) {
        throw DiagramSpecException(
          'Edge "$from" -> "$to": "$attrKey" "$attr" is not an attribute of '
          'entity node "$node".',
        );
      }
    }
  }

  final sizes = {
    for (final k in keys)
      k: entities[k]?.rect.size ?? _nodeSize(labels[k]!, shapes[k]!),
  };
  final tops = GraphLayout.layout(
    ids: keys,
    sizes: sizes,
    edges: pairs,
    direction: dir,
  );

  final boxes = <String, SketchElement>{};
  final centres = <String, Offset>{};
  for (final k in keys) {
    final topLeft = tops[k]! + origin;
    final size = sizes[k]!;
    final node = nodeMaps[k]!;
    if (entities.containsKey(k)) {
      boxes[k] = entities[k]!.translate(topLeft);
      centres[k] = topLeft + Offset(size.width / 2, size.height / 2);
      continue;
    }
    boxes[k] = parseDiagramElements([
      {
        'type': shapes[k],
        'x': topLeft.dx,
        'y': topLeft.dy,
        'width': size.width,
        'height': size.height,
        'text': labels[k],
        'fontSize': _fontSize,
        'fillColor': node['fillColor'],
        'strokeColor': node['strokeColor'],
      },
    ]).single;
    centres[k] = topLeft + Offset(size.width / 2, size.height / 2);
  }

  final arrows = <SketchElement>[];
  for (var i = 0; i < pairs.length; i++) {
    final (from, to) = pairs[i];
    final arrow =
        parseDiagramElements([
              {
                'type': 'arrow',
                'fromX': centres[from]!.dx,
                'fromY': centres[from]!.dy,
                'toX': centres[to]!.dx,
                'toY': centres[to]!.dy,
                'strokeColor': edgeMaps[i]['strokeColor'],
                'elbow': connectors == 'elbow',
                'startHead': edgeMaps[i]['fromCardinality'],
                'endHead': edgeMaps[i]['toCardinality'],
              },
            ]).single
            as SketchArrow;
    arrows.add(
      arrow.copyWith(
        startBinding: SketchBinding(
          elementId: boxes[from]!.id,
          attribute: edgeMaps[i]['fromAttribute'] as String?,
        ),
        endBinding: SketchBinding(
          elementId: boxes[to]!.id,
          attribute: edgeMaps[i]['toAttribute'] as String?,
        ),
      ),
    );
  }

  // Frames go first so they stack behind what they wrap.
  final frameElements = [
    for (final f in frames) _buildFrame(f, nodeMaps.keys.toSet(), boxes),
  ];

  return (
    elements: [...frameElements, ...boxes.values, ...arrows],
    nodeIds: {for (final k in keys) k: boxes[k]!.id},
  );
}

/// An edge's cardinality as the [ArrowheadStyle] name it must be, validated
/// here so the error names the edge rather than a bare `startHead`.
void _cardinality(
  Map<dynamic, dynamic> edge,
  String key,
  String from,
  String to,
) {
  final raw = edge[key];
  if (raw == null) return;
  if (raw is! String || !ArrowheadStyle.values.any((s) => s.name == raw)) {
    throw DiagramSpecException(
      'Edge "$from" -> "$to": unknown $key "$raw". Use one of '
      '${ArrowheadStyle.values.map((s) => s.name).join(', ')}.',
    );
  }
}

/// A frame around its members' laid-out bounds, inflated by [_framePadding].
///
/// The name's length is checked by the frame parse this routes through.
// ponytail: frames don't constrain ordering, so a non-member laid out between
// members falls inside the padded union; order members contiguously within
// ranks to fix.
SketchFrame _buildFrame(
  dynamic frame,
  Set<String> nodeKeys,
  Map<String, SketchElement> boxes,
) {
  if (frame is! Map) {
    throw DiagramSpecException('Frame must be an object, got: $frame');
  }
  final name = frame['name'] ?? '';
  final members = frame['members'];
  if (name is! String) {
    throw DiagramSpecException('Frame "name" must be a string, got: $name');
  }
  if (members is! List || members.isEmpty) {
    throw DiagramSpecException(
      'Frame "$name": "members" must be a non-empty list of node ids.',
    );
  }
  Rect? bounds;
  for (final m in members) {
    if (m is! String || !nodeKeys.contains(m)) {
      throw DiagramSpecException(
        'Frame "$name": member "$m" does not name a node id.',
      );
    }
    final b = boxes[m]!.bounds;
    bounds = bounds == null ? b : bounds.expandToInclude(b);
  }
  return parseDiagramElements([
        {
          'type': 'frame',
          'name': name,
          'x': bounds!.left - _framePadding,
          'y': bounds.top - _framePadding,
          'width': bounds.width + 2 * _framePadding,
          'height': bounds.height + 2 * _framePadding,
        },
      ]).single
      as SketchFrame;
}
