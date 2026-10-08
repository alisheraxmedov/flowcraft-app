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
}) {
  final dir = _directions[direction];
  if (dir == null) {
    throw DiagramSpecException(
      'Unknown direction "$direction". Use one of TB, LR, BT, RL.',
    );
  }
  if (nodes.isEmpty) {
    throw DiagramSpecException('"nodes" must be a non-empty list.');
  }
  if (nodes.length + edges.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${nodes.length + edges.length}. At most '
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
    final shape = node['shape'] ?? 'rectangle';
    if (!const {
      'rectangle',
      'ellipse',
      'diamond',
      'triangle',
    }.contains(shape)) {
      throw DiagramSpecException(
        'Node "$id": unknown shape "$shape". Use rectangle, ellipse, '
        'diamond or triangle.',
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

  final sizes = {for (final k in keys) k: _nodeSize(labels[k]!, shapes[k]!)};
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
              },
            ]).single
            as SketchArrow;
    arrows.add(
      arrow.copyWith(
        startBinding: SketchBinding(elementId: boxes[from]!.id),
        endBinding: SketchBinding(elementId: boxes[to]!.id),
      ),
    );
  }

  return (
    elements: [...boxes.values, ...arrows],
    nodeIds: {for (final k in keys) k: boxes[k]!.id},
  );
}
