import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('parseDiagramElements — bounded shapes', () {
    test('rectangle uses given fields', () {
      final elements = parseDiagramElements([
        {
          'type': 'rectangle',
          'x': 10,
          'y': 20,
          'width': 200,
          'height': 90,
          'text': 'UserService',
          'fontSize': 18,
          'strokeColor': '#1E88E5',
          'fillColor': '#DCEEFB',
        },
      ]);

      expect(elements, hasLength(1));
      final rect = elements.single as SketchRectangle;
      expect(rect.rect, const Rect.fromLTWH(10, 20, 200, 90));
      expect(rect.text, 'UserService');
      expect(rect.fontSize, 18);
      expect(rect.style.strokeColor, const Color(0xFF1E88E5));
      expect(rect.style.fillColor, const Color(0xFFDCEEFB));
    });

    test('rectangle falls back to defaults when fields are omitted', () {
      final elements = parseDiagramElements([
        {'type': 'rectangle'},
      ]);

      final rect = elements.single as SketchRectangle;
      expect(rect.rect, const Rect.fromLTWH(0, 0, 160, 80));
      expect(rect.text, isNull);
      expect(rect.fontSize, 16);
      expect(rect.style.strokeColor, const Color(0xFF1E1E1E));
      expect(rect.style.fillColor, isNull);
    });

    test('ellipse, diamond, and triangle map to their own types', () {
      final elements = parseDiagramElements([
        {'type': 'ellipse', 'width': 50, 'height': 50},
        {'type': 'diamond', 'width': 50, 'height': 50},
        {'type': 'triangle', 'width': 50, 'height': 50},
      ]);

      expect(elements[0], isA<SketchEllipse>());
      expect(elements[1], isA<SketchDiamond>());
      expect(elements[2], isA<SketchTriangle>());
    });

    test('sticky without an explicit color keeps its own default style', () {
      final withColor =
          parseDiagramElements([
                {'type': 'sticky', 'strokeColor': '#000000'},
              ]).single
              as SketchSticky;
      final withoutColor =
          parseDiagramElements([
                {'type': 'sticky'},
              ]).single
              as SketchSticky;

      expect(withColor.style.strokeColor, const Color(0xFF000000));
      expect(withoutColor.style, isNot(withColor.style));
    });
  });

  group('parseDiagramElements — text', () {
    test('creates a SketchText at the given position', () {
      final elements = parseDiagramElements([
        {'type': 'text', 'x': 5, 'y': 7, 'text': 'hello', 'fontSize': 20},
      ]);

      final text = elements.single as SketchText;
      expect(text.position, const Offset(5, 7));
      expect(text.text, 'hello');
      expect(text.fontSize, 20);
    });

    test('throws when "text" field is missing', () {
      expect(
        () => parseDiagramElements([
          {'type': 'text', 'x': 0, 'y': 0},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });
  });

  group('parseDiagramElements — linear shapes', () {
    test('arrow uses from/to coordinates', () {
      final elements = parseDiagramElements([
        {'type': 'arrow', 'fromX': 10, 'fromY': 20, 'toX': 30, 'toY': 40},
      ]);

      final arrow = elements.single as SketchArrow;
      expect(arrow.start, const Offset(10, 20));
      expect(arrow.end, const Offset(30, 40));
    });

    test('line defaults missing coordinates to zero', () {
      final elements = parseDiagramElements([
        {'type': 'line'},
      ]);

      final line = elements.single as SketchLine;
      expect(line.start, Offset.zero);
      expect(line.end, Offset.zero);
    });
  });

  group('parseDiagramElements — validation', () {
    test('throws for a non-object entry', () {
      expect(
        () => parseDiagramElements(['not an object']),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('throws when "type" is missing', () {
      expect(
        () => parseDiagramElements([
          {'x': 0},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('throws for an unknown element type', () {
      expect(
        () => parseDiagramElements([
          {'type': 'hexagon'},
        ]),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('hexagon'),
          ),
        ),
      );
    });

    test('throws for an invalid hex color', () {
      expect(
        () => parseDiagramElements([
          {'type': 'rectangle', 'strokeColor': 'not-a-color'},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('parses a 6-digit hex color as opaque', () {
      final elements = parseDiagramElements([
        {'type': 'rectangle', 'strokeColor': '2E7D32'},
      ]);

      final rect = elements.single as SketchRectangle;
      expect(rect.style.strokeColor, const Color(0xFF2E7D32));
    });

    test('parses an 8-digit hex color with its alpha', () {
      final elements = parseDiagramElements([
        {'type': 'rectangle', 'fillColor': '#802E7D32'},
      ]);

      expect(
        (elements.single as SketchRectangle).style.fillColor,
        const Color(0x802E7D32),
      );
    });

    test('refuses hex colors that only look like colors', () {
      // `int.tryParse` took a sign, and a 3-digit shorthand became a
      // nearly transparent black rather than the grey it was meant to be.
      for (final bad in [
        '#-1',
        '#FFF',
        'FFF',
        '#12345',
        '#1234567',
        '#123456789',
        '#GGGGGG',
        'red',
      ]) {
        expect(
          () => parseDiagramElements([
            {'type': 'rectangle', 'strokeColor': bad},
          ]),
          throwsA(
            isA<DiagramSpecException>().having(
              (e) => e.message,
              'message',
              contains('RRGGBB'),
            ),
          ),
          reason: bad,
        );
      }
    });

    test('non-string type/text/color fields are spec errors, not crashes', () {
      for (final (field, value) in [
        ('type', 5),
        ('text', 5),
        ('text', <String>[]),
        ('strokeColor', 0xFF0000),
        ('fillColor', true),
      ]) {
        expect(
          () => parseDiagramElements([
            {'type': 'rectangle', field: value},
          ]),
          throwsA(
            isA<DiagramSpecException>().having(
              (e) => e.message,
              'message',
              allOf(contains('must be'), contains('$value')),
            ),
          ),
          reason: '$field = $value',
        );
      }
    });

    test('text longer than the cap is refused', () {
      final atCap = 'x' * maxDiagramTextLength;
      expect(
        (parseDiagramElements([
                  {'type': 'text', 'text': atCap},
                ]).single
                as SketchText)
            .text,
        atCap,
        reason: 'the limit is inclusive',
      );

      for (final type in ['text', 'rectangle', 'sticky']) {
        expect(
          () => parseDiagramElements([
            {'type': type, 'text': '${atCap}x'},
          ]),
          throwsA(
            isA<DiagramSpecException>().having(
              (e) => e.message,
              'message',
              allOf(contains('too long'), contains('$maxDiagramTextLength')),
            ),
          ),
          reason: type,
        );
      }
    });

    test('refuses the non-finite numbers JSON can smuggle in', () {
      // `1e999` is the reachable spelling — there is no Infinity literal,
      // so a payload that looks like plain JSON produces one anyway.
      final decoded =
          jsonDecode(
                '[{"type":"rectangle","x":1,"y":2,"width":1e999,"height":10}]',
              )
              as List<dynamic>;
      expect((decoded.single as Map)['width'], double.infinity);

      expect(
        () => parseDiagramElements(decoded),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('finite'),
          ),
        ),
      );
    });

    test('refuses a non-finite value in every numeric field', () {
      const fields = {
        'rectangle': ['x', 'y', 'width', 'height'],
        'arrow': ['fromX', 'fromY', 'toX', 'toY'],
      };

      for (final entry in fields.entries) {
        for (final field in entry.value) {
          for (final bad in [
            double.infinity,
            double.negativeInfinity,
            double.nan,
          ]) {
            expect(
              () => parseDiagramElements([
                {'type': entry.key, field: bad},
              ]),
              throwsA(isA<DiagramSpecException>()),
              reason: '${entry.key}.$field = $bad',
            );
          }
        }
      }
    });

    test('refuses a finite value far outside any canvas', () {
      expect(
        () => parseDiagramElements([
          {'type': 'rectangle', 'x': 1e300},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('refuses a negative extent that would invert the rect', () {
      expect(
        () => parseDiagramElements([
          {'type': 'rectangle', 'width': -50},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('refuses a font size that is non-finite, zero, or unrenderable', () {
      for (final bad in [double.infinity, double.nan, 0, -12, 100000]) {
        expect(
          () => parseDiagramElements([
            {'type': 'text', 'text': 'hi', 'fontSize': bad},
          ]),
          throwsA(isA<DiagramSpecException>()),
          reason: 'fontSize = $bad',
        );
      }
    });

    test('refuses a numeric field that is not a number', () {
      expect(
        () => parseDiagramElements([
          {'type': 'rectangle', 'width': 'wide'},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('refuses more elements than one call may draw', () {
      final overLimit = [
        for (var i = 0; i <= maxDiagramElements; i++) {'type': 'line'},
      ];

      expect(
        () => parseDiagramElements(overLimit),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            // The model has to be able to act on this, not just be refused.
            allOf(contains('Too many elements'), contains('several calls')),
          ),
        ),
      );
      // The limit itself is inclusive — one below it still draws.
      expect(
        parseDiagramElements(overLimit.sublist(1)),
        hasLength(maxDiagramElements),
      );
    });

    test('processes multiple elements in order', () {
      final elements = parseDiagramElements([
        {'type': 'rectangle'},
        {'type': 'ellipse'},
        {'type': 'arrow'},
      ]);

      expect(elements, [
        isA<SketchRectangle>(),
        isA<SketchEllipse>(),
        isA<SketchArrow>(),
      ]);
    });
  });

  group('describeDiagramElement', () {
    test('describes a bounded shape with the draw vocabulary plus id', () {
      final rect = SketchRectangle.create(
        id: 'r1',
        rect: const Rect.fromLTWH(10, 20, 200, 90),
        style: const SketchStyle(
          strokeColor: Color(0xFF1E88E5),
          fillColor: Color(0x80DCEEFB),
        ),
        text: 'UserService',
        fontSize: 18,
      );

      expect(describeDiagramElement(rect), {
        'id': 'r1',
        'type': 'rectangle',
        'x': 10.0,
        'y': 20.0,
        'width': 200.0,
        'height': 90.0,
        'text': 'UserService',
        'fontSize': 18.0,
        // Eight digits, alpha first, so `_color` reads it back unchanged.
        'strokeColor': '#ff1e88e5',
        'fillColor': '#80dceefb',
      });
    });

    test('omits text/fontSize for an unlabelled shape and fill when none', () {
      final ellipse = SketchEllipse.create(
        id: 'e1',
        rect: const Rect.fromLTWH(0, 0, 50, 50),
      );
      final described = describeDiagramElement(ellipse);

      expect(described['type'], 'ellipse');
      expect(described.containsKey('text'), isFalse);
      expect(described.containsKey('fontSize'), isFalse);
      expect(described.containsKey('fillColor'), isFalse);
    });

    test('describes a text element by position, text and stroke', () {
      final text = SketchText.create(
        id: 't1',
        position: const Offset(5, 7),
        text: 'hello',
        fontSize: 20,
      );
      final described = describeDiagramElement(text);

      expect(described['id'], 't1');
      expect(described['type'], 'text');
      expect(described['x'], 5.0);
      expect(described['y'], 7.0);
      expect(described['text'], 'hello');
      expect(described['fontSize'], 20.0);
      expect(described['strokeColor'], isA<String>());
    });

    test('describes a line/arrow by its endpoints', () {
      final arrow = SketchArrow.create(
        id: 'a1',
        start: const Offset(10, 20),
        end: const Offset(30, 40),
      );

      expect(describeDiagramElement(arrow), {
        'id': 'a1',
        'type': 'arrow',
        'fromX': 10.0,
        'fromY': 20.0,
        'toX': 30.0,
        'toY': 40.0,
        'strokeColor': '#ff1e1e1e',
      });
    });

    test('lists a freedraw by its bounding box and stroke only', () {
      final freedraw = SketchFreedraw.create(
        id: 'f1',
        points: const [Offset(0, 0), Offset(30, 40)],
        style: const SketchStyle(strokeColor: Color(0xFF000000)),
      );
      final described = describeDiagramElement(freedraw);

      expect(described['type'], 'freedraw');
      expect(described['x'], 0.0);
      expect(described['y'], 0.0);
      expect(described['width'], 30.0);
      expect(described['height'], 40.0);
      expect(described['strokeColor'], '#ff000000');
      expect(described.containsKey('text'), isFalse);
    });

    test('describeDiagramElements preserves order', () {
      final described = describeDiagramElements([
        SketchRectangle.create(
          id: 'r',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
        SketchArrow.create(
          id: 'a',
          start: Offset.zero,
          end: const Offset(1, 1),
        ),
      ]);

      expect(described.map((e) => e['id']), ['r', 'a']);
      expect(described.map((e) => e['type']), ['rectangle', 'arrow']);
    });
  });

  group('applyDiagramPatch', () {
    test('overrides only the named fields, preserving identity', () {
      final rect = SketchRectangle(
        id: 'r1',
        style: const SketchStyle(strokeColor: Color(0xFF123456)),
        rect: const Rect.fromLTWH(5, 6, 100, 50),
        text: 'Old',
        fontSize: 16,
        angle: 0.4,
        groupId: 'g1',
      );

      final patched =
          applyDiagramPatch(rect, {
                'x': 20,
                'text': 'New',
                'strokeColor': '#FF0000',
              })
              as SketchRectangle;

      expect(patched.rect, const Rect.fromLTWH(20, 6, 100, 50));
      expect(patched.text, 'New');
      expect(patched.style.strokeColor, const Color(0xFFFF0000));
      // Everything the patch didn't touch survives, identity included.
      expect(patched.id, 'r1');
      expect(patched.angle, 0.4);
      expect(patched.groupId, 'g1');
      expect(patched.fontSize, 16);
    });

    test('describe then re-apply is a round-trip for the shared fields', () {
      final rect = SketchRectangle(
        id: 'r1',
        style: const SketchStyle(
          strokeColor: Color(0xFF1E88E5),
          fillColor: Color(0x80DCEEFB),
        ),
        rect: const Rect.fromLTWH(5, 6, 100, 50),
        text: 'Hi',
        fontSize: 18,
        angle: 0.4,
        groupId: 'g1',
      );

      final described = describeDiagramElement(rect).cast<String, dynamic>();
      final rebuilt = applyDiagramPatch(rect, described) as SketchRectangle;

      expect(rebuilt.rect, rect.rect);
      expect(rebuilt.text, 'Hi');
      expect(rebuilt.fontSize, 18);
      expect(rebuilt.style.strokeColor, const Color(0xFF1E88E5));
      expect(rebuilt.style.fillColor, const Color(0x80DCEEFB));
      expect(rebuilt.id, 'r1');
      expect(rebuilt.angle, 0.4);
      expect(rebuilt.groupId, 'g1');
    });

    test('an empty text clears a bounded shape\'s label', () {
      final rect = SketchRectangle.create(
        id: 'r1',
        rect: const Rect.fromLTWH(0, 0, 100, 50),
        text: 'label',
      );

      expect(
        (applyDiagramPatch(rect, {'text': ''}) as SketchRectangle).text,
        isNull,
      );
    });

    test('a line patch overrides endpoints and stroke, keeps the rest', () {
      final line = SketchLine.create(
        id: 'l1',
        start: const Offset(0, 0),
        end: const Offset(10, 10),
      );

      final moved =
          applyDiagramPatch(line, {
                'toX': 50,
                'toY': 60,
                'strokeColor': '#112233',
              })
              as SketchLine;

      expect(moved.start, const Offset(0, 0));
      expect(moved.end, const Offset(50, 60));
      expect(moved.style.strokeColor, const Color(0xFF112233));
      expect(moved.id, 'l1');
    });

    test('changing an element type is refused', () {
      final rect = SketchRectangle.create(
        id: 'r1',
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      );

      expect(
        () => applyDiagramPatch(rect, {'type': 'ellipse'}),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            allOf(contains('type'), contains('rectangle')),
          ),
        ),
      );
    });

    test('emptying a text element is refused (delete it instead)', () {
      final text = SketchText.create(
        id: 't1',
        position: Offset.zero,
        text: 'hello',
      );

      expect(
        () => applyDiagramPatch(text, {'text': ''}),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('flowcraft_delete'),
          ),
        ),
      );
    });

    test('a freedraw rejects geometry patches but accepts a recolour', () {
      final freedraw = SketchFreedraw.create(
        id: 'f1',
        points: const [Offset(0, 0), Offset(10, 10)],
      );

      for (final geometry in [
        {'x': 5},
        {'width': 20},
        {'fromX': 1},
        {'text': 'no'},
      ]) {
        expect(
          () => applyDiagramPatch(freedraw, geometry),
          throwsA(isA<DiagramSpecException>()),
          reason: '$geometry',
        );
      }

      final recoloured =
          applyDiagramPatch(freedraw, {'strokeColor': '#00FF00'})
              as SketchFreedraw;
      expect(recoloured.style.strokeColor, const Color(0xFF00FF00));
      expect(recoloured.points, freedraw.points);
      expect(recoloured.id, 'f1');
    });

    test('reuses the draw validators for range, finiteness and hex', () {
      final rect = SketchRectangle.create(
        id: 'r1',
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      );

      expect(
        () => applyDiagramPatch(rect, {'width': -5}),
        throwsA(isA<DiagramSpecException>()),
      );
      expect(
        () => applyDiagramPatch(rect, {'x': 1e300}),
        throwsA(isA<DiagramSpecException>()),
      );
      expect(
        () => applyDiagramPatch(rect, {'strokeColor': 'not-a-color'}),
        throwsA(isA<DiagramSpecException>()),
      );

      // `1e999` is the only way a non-finite number reaches the parser —
      // there is no Infinity literal in JSON.
      final nonFinite = jsonDecode('{"width":1e999}') as Map<String, dynamic>;
      expect(
        () => applyDiagramPatch(rect, nonFinite),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('finite'),
          ),
        ),
      );
    });
  });

  group('arrow bindings', () {
    final ids = {'a', 'b'};
    Map<String, dynamic> arrow(Map<String, dynamic> extra) => {
      'type': 'arrow',
      ...extra,
    };
    SketchArrow parse(Map<String, dynamic> m) =>
        parseDiagramElements([m], bindableIds: ids).single as SketchArrow;
    Matcher refuses(String part) => throwsA(
      isA<DiagramSpecException>().having(
        (e) => e.message,
        'message',
        contains(part),
      ),
    );

    test('fromId/toId parse to bindings', () {
      final a = parse(arrow({'fromId': 'a', 'toId': 'b'}));
      expect(a.startBinding?.elementId, 'a');
      expect(a.endBinding?.elementId, 'b');
    });

    test('a bound end without coordinates borrows the other end', () {
      final a = parse(arrow({'fromId': 'a', 'toX': 50, 'toY': 60}));
      expect(a.start, const Offset(50, 60));
    });

    test('empty string means no binding', () {
      final a = parse(arrow({'fromId': '', 'toId': ''}));
      expect(a.startBinding, isNull);
      expect(a.endBinding, isNull);
    });

    test('unknown or unbindable id is rejected', () {
      expect(
        () => parse(arrow({'toId': 'zzz'})),
        throwsA(isA<DiagramSpecException>()),
      );
      // Default bindableIds refuses everything (legacy REST path).
      expect(
        () => parseDiagramElements([
          arrow({'fromId': 'a'}),
        ]),
        refuses('not a shape'),
      );
    });

    test('fromId == toId is rejected', () {
      expect(
        () => parse(arrow({'fromId': 'a', 'toId': 'a'})),
        refuses('same shape'),
      );
    });

    test('fromId on a non-arrow is rejected', () {
      expect(
        () => parseDiagramElements([
          {'type': 'line', 'fromId': 'a'},
        ], bindableIds: ids),
        refuses('only applies to arrows'),
      );
    });

    group('applyDiagramPatch', () {
      final bound =
          SketchArrow.create(
            start: const Offset(1, 2),
            end: const Offset(3, 4),
          ).copyWith(
            startBinding: const SketchBinding(elementId: 'a'),
            endBinding: const SketchBinding(elementId: 'b'),
          );
      SketchArrow patch(SketchArrow el, Map<String, dynamic> p) =>
          applyDiagramPatch(el, p, bindableIds: ids) as SketchArrow;

      test('fromId binds, "" detaches', () {
        final unbound = SketchArrow.create(
          start: Offset.zero,
          end: const Offset(5, 5),
        );
        expect(patch(unbound, {'fromId': 'a'}).startBinding?.elementId, 'a');
        expect(patch(bound, {'fromId': ''}).startBinding, isNull);
        expect(patch(bound, {'fromId': ''}).endBinding?.elementId, 'b');
      });

      test('fromX alone clears the start binding only', () {
        final r = patch(bound, {'fromX': 9});
        expect(r.startBinding, isNull);
        expect(r.endBinding?.elementId, 'b');
      });

      test('untouched fields keep both bindings', () {
        final r = patch(bound, {'strokeColor': '#FF0000'});
        expect(r.startBinding?.elementId, 'a');
        expect(r.endBinding?.elementId, 'b');
      });

      test('unknown id and self loop are rejected', () {
        expect(
          () => patch(bound, {'toId': 'nope'}),
          throwsA(isA<DiagramSpecException>()),
        );
        expect(() => patch(bound, {'toId': 'a'}), refuses('same shape'));
      });
    });

    test('describe emits fromId/toId only when bound', () {
      final plain = SketchArrow.create(
        start: Offset.zero,
        end: const Offset(1, 1),
      );
      expect(describeDiagramElement(plain).containsKey('fromId'), isFalse);
      expect(describeDiagramElement(plain).containsKey('toId'), isFalse);
      final half = plain.copyWith(
        startBinding: const SketchBinding(elementId: 'a'),
      );
      final d = describeDiagramElement(half);
      expect(d['fromId'], 'a');
      expect(d.containsKey('toId'), isFalse);
    });
  });

  group('phase 2 vocabulary', () {
    Map<String, Object?> noId(SketchElement el) =>
        describeDiagramElement(el)..remove('id');

    /// parse -> describe -> parse; the second description must equal the first.
    SketchElement roundTrip(
      Map<String, Object?> input, {
      Set<String> bindable = const {},
      Map<String, SketchEntity> entities = const {},
    }) {
      final first = parseDiagramElements(
        [input],
        bindableIds: bindable,
        entities: entities,
      ).single;
      final second = parseDiagramElements(
        [describeDiagramElement(first)],
        bindableIds: bindable,
        entities: entities,
      ).single;
      expect(noId(second), noId(first));
      return first;
    }

    String b64(int n) => base64Encode(Uint8List(n)..fillRange(0, n, 7));

    test('frame round-trips', () {
      final f =
          roundTrip({
                'type': 'frame',
                'x': 5,
                'y': 6,
                'width': 300,
                'height': 200,
                'name': 'Backend',
              })
              as SketchFrame;
      expect(f.rect, const Rect.fromLTWH(5, 6, 300, 200));
      expect(f.name, 'Backend');
    });

    test('icon round-trips and defaults to 64x64', () {
      final i =
          roundTrip({'type': 'icon', 'x': 1, 'y': 2, 'name': 'database'})
              as SketchIcon;
      expect(i.rect, const Rect.fromLTWH(1, 2, 64, 64));
    });

    test('unknown icon lists the valid names', () {
      expect(
        () => parseDiagramElements([
          {'type': 'icon', 'name': 'nope'},
        ]),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            allOf(contains('database'), contains('terminal')),
          ),
        ),
      );
    });

    test('image round-trips', () {
      final img =
          roundTrip({
                'type': 'image',
                'x': 0,
                'y': 0,
                'width': 40,
                'height': 30,
                'mimeType': 'image/png',
                'data': b64(10),
              })
              as SketchImage;
      expect(img.bytes, hasLength(10));
      expect(img.mimeType, 'image/png');
    });

    test('image rejects bad mime, oversize, and the per-batch cap', () {
      Map<String, Object?> image(String mime, String data) => {
        'type': 'image',
        'width': 10,
        'height': 10,
        'mimeType': mime,
        'data': data,
      };
      expect(
        () => parseDiagramElements([image('image/svg+xml', b64(4))]),
        throwsA(isA<DiagramSpecException>()),
      );
      expect(
        () =>
            parseDiagramElements([image('image/png', b64(maxImageBytes + 1))]),
        throwsA(isA<DiagramSpecException>()),
      );
      final big = b64(maxImageBytes - 1024);
      expect(
        () => parseDiagramElements([
          for (var i = 0; i < 5; i++) image('image/png', big),
        ]),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('add up'),
          ),
        ),
      );
      // Four of them still fit.
      expect(
        parseDiagramElements([
          for (var i = 0; i < 4; i++) image('image/png', big),
        ]),
        hasLength(4),
      );
    });

    test('entity round-trips with height derived from the rows', () {
      final e =
          roundTrip({
                'type': 'entity',
                'x': 10,
                'y': 20,
                'width': 220,
                'name': 'users',
                'attributes': [
                  {'name': 'id', 'type': 'int', 'pk': true},
                  {'name': 'org_id', 'type': 'int', 'fk': true},
                  {'name': 'email'},
                ],
              })
              as SketchEntity;
      expect(e.rect.height, e.fittedHeight);
      expect(e.attributes[0].primaryKey, isTrue);
      expect(e.attributes[1].foreignKey, isTrue);
    });

    test('entity rejects duplicate attributes', () {
      expect(
        () => parseDiagramElements([
          {
            'type': 'entity',
            'name': 't',
            'attributes': [
              {'name': 'a'},
              {'name': 'a'},
            ],
          },
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('elbow arrow with heads and attribute bindings round-trips', () {
      final entity = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'users',
        attributes: const [EntityAttribute(name: 'id')],
      );
      final other = SketchEntity.create(
        rect: const Rect.fromLTWH(300, 0, 200, 0),
        name: 'orders',
        attributes: const [EntityAttribute(name: 'user_id')],
      );
      final a =
          roundTrip(
                {
                  'type': 'arrow',
                  'fromId': entity.id,
                  'toId': other.id,
                  'fromAttribute': 'id',
                  'toAttribute': 'user_id',
                  'elbow': true,
                  'startHead': 'one',
                  'endHead': 'zeroOrMany',
                },
                bindable: {entity.id, other.id},
                entities: {entity.id: entity, other.id: other},
              )
              as SketchArrow;
      expect(a.elbowed, isTrue);
      expect(a.startHead, ArrowheadStyle.one);
      expect(a.endHead, ArrowheadStyle.zeroOrMany);
      expect(a.startBinding?.attribute, 'id');
      expect(a.endBinding?.attribute, 'user_id');
    });

    test('attribute needs an id and a real row on an entity', () {
      final entity = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'users',
        attributes: const [EntityAttribute(name: 'id')],
      );
      final ids = {entity.id};
      final ents = {entity.id: entity};
      expect(
        () => parseDiagramElements([
          {'type': 'arrow', 'toX': 5, 'toY': 5, 'fromAttribute': 'id'},
        ], entities: ents),
        throwsA(isA<DiagramSpecException>()),
      );
      expect(
        () => parseDiagramElements(
          [
            {
              'type': 'arrow',
              'fromId': entity.id,
              'toX': 5,
              'toY': 5,
              'fromAttribute': 'missing',
            },
          ],
          bindableIds: ids,
          entities: ents,
        ),
        throwsA(
          isA<DiagramSpecException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('patching an arrow keeps its row unless told otherwise', () {
      final entity = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'users',
        attributes: const [
          EntityAttribute(name: 'id'),
          EntityAttribute(name: 'x'),
        ],
      );
      final arrow =
          (parseDiagramElements(
                [
                  {
                    'type': 'arrow',
                    'fromId': entity.id,
                    'toX': 9,
                    'toY': 9,
                    'fromAttribute': 'id',
                  },
                ],
                bindableIds: {entity.id},
                entities: {entity.id: entity},
              ).single
              as SketchArrow);
      final recoloured =
          applyDiagramPatch(arrow, {'strokeColor': '#FF0000'}) as SketchArrow;
      expect(recoloured.startBinding?.attribute, 'id');
      final moved =
          applyDiagramPatch(
                arrow,
                {'fromAttribute': 'x', 'elbow': true},
                entities: {entity.id: entity},
              )
              as SketchArrow;
      expect(moved.startBinding?.attribute, 'x');
      expect(moved.elbowed, isTrue);
    });

    test('text style round-trips on text and labelled shapes', () {
      final t =
          roundTrip({
                'type': 'text',
                'x': 0,
                'y': 0,
                'text': 'a\nlonger',
                'fontFamily': 'mono',
                'bold': true,
                'align': 'center',
              })
              as SketchText;
      expect(t.fontFamily, 'mono');
      expect(t.bold, isTrue);
      expect(t.align, TextAlign.center);
      final r =
          roundTrip({
                'type': 'rectangle',
                'text': 'x',
                'fontFamily': 'sans',
                'bold': true,
              })
              as SketchRectangle;
      expect(r.fontFamily, 'sans');
      expect(r.bold, isTrue);
    });

    test('rejects an unknown font family, and align on a non-text', () {
      expect(
        () => parseDiagramElements([
          {'type': 'text', 'text': 'x', 'fontFamily': 'hand'},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
      expect(
        () => parseDiagramElements([
          {'type': 'rectangle', 'text': 'x', 'align': 'center'},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('patch updates frame, icon and entity', () {
      final frame = parseDiagramElements([
        {'type': 'frame', 'name': 'a'},
      ]).single;
      expect(
        (applyDiagramPatch(frame, {'name': 'b'}) as SketchFrame).name,
        'b',
      );
      final icon = parseDiagramElements([
        {'type': 'icon', 'name': 'cloud'},
      ]).single;
      expect(
        () => applyDiagramPatch(icon, {'name': 'nope'}),
        throwsA(isA<DiagramSpecException>()),
      );
      final entity =
          parseDiagramElements([
                {
                  'type': 'entity',
                  'name': 't',
                  'attributes': [
                    {'name': 'a'},
                  ],
                },
              ]).single
              as SketchEntity;
      final grown =
          applyDiagramPatch(entity, {
                'attributes': [
                  {'name': 'a'},
                  {'name': 'b'},
                ],
              })
              as SketchEntity;
      expect(grown.rect.height, grown.fittedHeight);
      expect(grown.rect.height, greaterThan(entity.rect.height));
    });

    test('frames are partitioned to the front, order otherwise stable', () {
      final out = parseDiagramElements([
        {'type': 'rectangle', 'text': 'one'},
        {'type': 'frame', 'name': 'f1'},
        {'type': 'rectangle', 'text': 'two'},
        {'type': 'frame', 'name': 'f2'},
      ]);
      expect(out.map((e) => e.runtimeType), [
        SketchFrame,
        SketchFrame,
        SketchRectangle,
        SketchRectangle,
      ]);
      expect((out[0] as SketchFrame).name, 'f1');
      expect((out[2] as SketchRectangle).text, 'one');
    });
  });

  group('review fixes', () {
    final long = 'x' * (maxDiagramTextLength + 1);

    test('frame name over the text cap rejected', () {
      expect(
        () => parseDiagramElements([
          {'type': 'frame', 'name': long, 'width': 10, 'height': 10},
        ]),
        throwsA(isA<DiagramSpecException>()),
      );
      final frame =
          parseDiagramElements([
                {'type': 'frame', 'name': 'ok', 'width': 10, 'height': 10},
              ]).single
              as SketchFrame;
      expect(
        () => applyDiagramPatch(frame, {'name': long}),
        throwsA(isA<DiagramSpecException>()),
      );
    });

    test('read → update round trip keeps the attribute anchor', () {
      final a = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'users',
        attributes: const [EntityAttribute(name: 'id')],
      );
      final b = SketchEntity.create(
        rect: const Rect.fromLTWH(300, 0, 200, 0),
        name: 'orders',
        attributes: const [EntityAttribute(name: 'user_id')],
      );
      final arrow =
          SketchArrow.create(
            start: const Offset(200, 10),
            end: const Offset(300, 10),
          ).copyWith(
            startBinding: SketchBinding(
              elementId: a.id,
              attribute: 'id',
              focus: 0.3,
              gap: 7,
            ),
          );
      final back =
          applyDiagramPatch(
                arrow,
                describeDiagramElement(arrow).cast<String, dynamic>(),
                bindableIds: {a.id, b.id},
                entities: {a.id: a, b.id: b},
              )
              as SketchArrow;
      expect(back.startBinding, arrow.startBinding);
    });
  });
}
