import 'dart:convert';
import 'dart:ui';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/text_import/excalidraw.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> base(String type, String id, num x, num y) => {
  'type': type,
  'id': id,
  'x': x,
  'y': y,
  'width': 100,
  'height': 50,
  'strokeColor': '#e03131',
  'backgroundColor': '#a5d8ff',
  'strokeWidth': 4,
  'opacity': 50,
  'roughness': 2,
};

String scene(List<Object> els) =>
    jsonEncode({'type': 'excalidraw', 'version': 2, 'elements': els});

void main() {
  test('shapes, label, bound arrow, style; unknown dropped and counted', () {
    final r = parseExcalidraw(
      scene([
        base('rectangle', 'r1', 0, 0),
        base('ellipse', 'e1', 300, 0),
        {
          ...base('text', 't1', 10, 10),
          'text': 'Hello',
          'fontSize': 20,
          'containerId': 'r1',
        },
        {
          ...base('arrow', 'a1', 100, 25),
          'points': [
            [0, 0],
            [100, 10],
            [200, 0],
          ],
          'startBinding': {'elementId': 'r1', 'focus': 0.1, 'gap': 4},
          'endBinding': {'elementId': 'e1', 'focus': 5, 'gap': 4},
        },
        {...base('text', 't2', 0, 0), 'text': 'on arrow', 'containerId': 'a1'},
        {...base('text', 't3', 5, 200), 'text': 'free'},
        {
          ...base('line', 'l1', 0, 300),
          'points': [
            [0, 0],
            [50, 50],
          ],
        },
        {
          ...base('freedraw', 'f1', 10, 10),
          'points': [
            [0, 0],
            [3, 4],
          ],
        },
        {...base('image', 'i1', 0, 0)},
        {...base('rectangle', 'gone', 0, 0), 'isDeleted': true},
        'garbage',
      ]),
    );
    expect(r.dropped, 3); // image, arrow label, 'garbage'
    final rect = r.elements.whereType<SketchRectangle>().single;
    final ell = r.elements.whereType<SketchEllipse>().single;
    expect(rect.text, 'Hello');
    expect(rect.fontSize, 20);
    expect(rect.rect, const Rect.fromLTWH(0, 0, 100, 50));
    expect(rect.style.strokeColor, const Color(0xFFE03131));
    expect(rect.style.fillColor, const Color(0xFFA5D8FF));
    expect(rect.style.fillStyle, FillStyle.solid);
    expect(rect.style.strokeWidth, 4);
    expect(rect.style.opacity, 0.5);
    expect(rect.style.roughness, 2);
    expect(r.elements.whereType<SketchText>().single.text, 'free');
    expect(r.elements.whereType<SketchLine>().length, 1);
    expect(
      r.elements.whereType<SketchFreedraw>().single.points.last,
      const Offset(13, 14),
    );

    final arrow = r.elements.whereType<SketchArrow>().single;
    expect(arrow.start, const Offset(100, 25));
    expect(arrow.end, const Offset(300, 25)); // chord first->last
    expect(arrow.startBinding!.elementId, rect.id);
    expect(arrow.endBinding!.elementId, ell.id);
    expect(arrow.endBinding!.focus, 1.0); // clamped
    expect(rect.id, isNot('r1'));
    expect(r.elements.map((e) => e.id).toSet().length, r.elements.length);
  });

  test('binding to a missing element is dropped, not dangling', () {
    final r = parseExcalidraw(
      scene([
        {
          ...base('arrow', 'a1', 0, 0),
          'points': [
            [0, 0],
            [10, 10],
          ],
          'startBinding': {'elementId': 'nope'},
        },
      ]),
    );
    expect((r.elements.single as SketchArrow).startBinding, isNull);
  });

  test('untrusted input fails cleanly', () {
    expect(
      () => parseExcalidraw('not json'),
      throwsA(isA<DiagramSpecException>()),
    );
    expect(
      () => parseExcalidraw('{"a":1}'),
      throwsA(isA<DiagramSpecException>()),
    );
    final bad = parseExcalidraw(
      scene([
        {'type': 'rectangle', 'id': 'x', 'x': 'oops', 'y': 1},
        {'type': 'arrow', 'id': 'y', 'x': 1, 'y': 1, 'points': 'zzz'},
      ]),
    );
    expect(bad.elements, isEmpty);
    expect(bad.dropped, 2);
  });

  test('element cap enforced', () {
    expect(
      () => parseExcalidraw(
        scene([for (var i = 0; i < 10001; i++) base('rectangle', '$i', 0, 0)]),
      ),
      throwsA(isA<DiagramSpecException>()),
    );
  });
}
