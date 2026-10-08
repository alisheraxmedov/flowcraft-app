import 'dart:ui';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/diagram_layout.dart';
import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nodes = [
    {
      'id': 'a',
      'label': 'Alpha',
      'fillColor': 'FFCC00',
      'strokeColor': '112233',
    },
    {'id': 'b', 'label': 'Beta', 'shape': 'ellipse'},
  ];
  final edges = [
    {'from': 'a', 'to': 'b'},
  ];

  test('node elements carry label, shape and colours and map to keys', () {
    final built = buildDiagram(nodes: nodes, edges: edges);

    final a =
        built.elements.firstWhere((e) => e.id == built.nodeIds['a'])
            as SketchRectangle;
    final b = built.elements.firstWhere((e) => e.id == built.nodeIds['b']);
    expect(a.text, 'Alpha');
    expect(a.style.fillColor, const Color(0xFFFFCC00));
    expect(a.style.strokeColor, const Color(0xFF112233));
    expect(b, isA<SketchEllipse>());
  });

  test('edges are arrows bound at both ends to the node ids', () {
    final built = buildDiagram(nodes: nodes, edges: edges);

    final arrow = built.elements.whereType<SketchArrow>().single;
    expect(arrow.startBinding?.elementId, built.nodeIds['a']);
    expect(arrow.endBinding?.elementId, built.nodeIds['b']);
  });

  test('ellipse and diamond boxes are larger than a rectangle', () {
    Rect rectFor(String shape) {
      final built = buildDiagram(
        nodes: [
          {'id': 'n', 'label': 'Same', 'shape': shape},
        ],
        edges: const [],
      );
      return built.elements.single.bounds;
    }

    final rect = rectFor('rectangle');
    expect(rectFor('ellipse').width, greaterThan(rect.width));
    expect(rectFor('diamond').width, greaterThan(rectFor('ellipse').width));
    expect(rectFor('diamond').height, greaterThan(rect.height));
  });

  test('origin shifts all nodes', () {
    Rect first(Offset origin) => buildDiagram(
      nodes: nodes,
      edges: edges,
      origin: origin,
    ).elements.first.bounds;

    final shifted =
        first(const Offset(300, 200)).topLeft - first(Offset.zero).topLeft;
    expect(shifted, const Offset(300, 200));
  });

  group('rejects', () {
    void bad(String name, Map<String, Object?> args) {
      test(name, () {
        expect(
          () => buildDiagram(
            nodes: args['nodes'] as List? ?? nodes,
            edges: args['edges'] as List? ?? edges,
            direction: args['direction'] as String? ?? 'TB',
          ),
          throwsA(isA<DiagramSpecException>()),
        );
      });
    }

    bad('duplicate ids', {
      'nodes': [
        {'id': 'a'},
        {'id': 'a'},
      ],
      'edges': [],
    });
    bad('an unknown edge endpoint', {
      'edges': [
        {'from': 'a', 'to': 'zzz'},
      ],
    });
    bad('a self-loop', {
      'edges': [
        {'from': 'a', 'to': 'a'},
      ],
    });
    bad('a bad direction', {'direction': 'UP'});
    bad('a bad shape', {
      'nodes': [
        {'id': 'a', 'shape': 'hexagon'},
      ],
      'edges': [],
    });
    bad('empty nodes', {'nodes': [], 'edges': []});
    bad('more than the element cap', {
      'nodes': [
        for (var i = 0; i < maxDiagramElements + 1; i++) {'id': 'n$i'},
      ],
      'edges': [],
    });
  });
}
