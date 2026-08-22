import 'dart:convert';
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
      final withColor = parseDiagramElements([
        {'type': 'sticky', 'strokeColor': '#000000'},
      ]).single as SketchSticky;
      final withoutColor = parseDiagramElements([
        {'type': 'sticky'},
      ]).single as SketchSticky;

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
      for (final bad in ['#-1', '#FFF', 'FFF', '#12345', '#1234567',
          '#123456789', '#GGGGGG', 'red']) {
        expect(
          () => parseDiagramElements([
            {'type': 'rectangle', 'strokeColor': bad},
          ]),
          throwsA(
            isA<DiagramSpecException>()
                .having((e) => e.message, 'message', contains('RRGGBB')),
          ),
          reason: bad,
        );
      }
    });

    test('non-string type/text/color fields are spec errors, not crashes',
        () {
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
        ]).single as SketchText)
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
      final decoded = jsonDecode(
        '[{"type":"rectangle","x":1,"y":2,"width":1e999,"height":10}]',
      ) as List<dynamic>;
      expect((decoded.single as Map)['width'], double.infinity);

      expect(
        () => parseDiagramElements(decoded),
        throwsA(
          isA<DiagramSpecException>()
              .having((e) => e.message, 'message', contains('finite')),
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
}
