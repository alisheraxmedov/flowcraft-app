import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/serialization/sketch_serializer.dart';

void main() {
  group('SketchSerializer.serialize / deserialize', () {
    test('round-trips a mixed element list', () {
      final source = <SketchElement>[
        SketchRectangle.create(
          rect: const Rect.fromLTWH(10, 20, 100, 50),
          style: const SketchStyle(roughness: 1.4, seed: 42),
        ),
        SketchEllipse.create(
          rect: const Rect.fromLTWH(0, 0, 80, 80),
          style: const SketchStyle(
            fillStyle: FillStyle.solid,
            fillColor: Color(0xFFFF0000),
          ),
        ),
        SketchLine.create(
          start: const Offset(0, 0),
          end: const Offset(100, 100),
        ),
        SketchArrow.create(
          start: const Offset(0, 0),
          end: const Offset(50, 25),
          arrowSize: 14,
        ),
        SketchFreedraw.create(
          points: const [
            Offset(0, 0),
            Offset(10, 5),
            Offset(20, 0),
          ],
        ),
        SketchText.create(
          position: const Offset(40, 40),
          text: 'hello',
          fontSize: 18,
        ),
      ];

      final json = SketchSerializer.serialize(source);
      final restored = SketchSerializer.deserialize(json);

      expect(restored.length, source.length);
      for (var i = 0; i < source.length; i++) {
        expect(restored[i].runtimeType, source[i].runtimeType);
        expect(restored[i].id, source[i].id);
        expect(restored[i].bounds, source[i].bounds);
        expect(restored[i].style, source[i].style);
      }
    });

    test('rejects newer schema versions', () {
      expect(
        () => SketchSerializer.fromMap({
          'version': SketchSerializer.schemaVersion + 1,
          'elements': const [],
        }),
        throwsStateError,
      );
    });

    test('simplifies freedraw points on write', () {
      // Long noisy polyline whose colinear segments should collapse.
      final points = <Offset>[
        for (var i = 0; i < 50; i++) Offset(i.toDouble(), 0),
      ];
      final original = SketchFreedraw.create(points: points);
      final map = SketchSerializer.toMap([original]);
      final encoded = (map['elements'] as List).first as Map<String, dynamic>;
      final encodedPoints = encoded['points'] as List;
      expect(encodedPoints.length, lessThan(points.length));
    });
  });
}
