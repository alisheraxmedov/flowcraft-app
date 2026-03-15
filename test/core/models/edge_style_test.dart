import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('EdgeStyle', () {
    test('default values: animated=true, color=blue', () {
      const style = EdgeStyle();
      expect(style.color, const Color(0xFF42A5F5));
      expect(style.animated, isTrue);
      expect(style.thickness, 2.0);
      expect(style.edgeType, EdgeType.bezier);
      expect(style.dashPattern, isEmpty);
      expect(style.arrowSize, 8.0);
      expect(style.showArrow, isTrue);
      expect(style.label, isNull);
    });

    test('value equality', () {
      const style1 = EdgeStyle(
        color: Color(0xFF000000),
        thickness: 2.0,
        edgeType: EdgeType.bezier,
        animated: true,
        dashPattern: [10.0, 5.0],
      );
      const style2 = EdgeStyle(
        color: Color(0xFF000000),
        thickness: 2.0,
        edgeType: EdgeType.bezier,
        animated: true,
        dashPattern: [10.0, 5.0],
      );
      const style3 = EdgeStyle(
        color: Color(0xFF000000),
        thickness: 2.0,
        edgeType: EdgeType.bezier,
        animated: true,
        dashPattern: [5.0, 5.0],
      );

      expect(style1, style2);
      expect(style1.hashCode, style2.hashCode);
      expect(style1, isNot(style3));
    });

    test('toJson/fromJson round-trip', () {
      const style = EdgeStyle(
        color: Color(0xFF123456),
        thickness: 3.5,
        edgeType: EdgeType.smoothStep,
        animated: false,
        dashPattern: [8.0],
        showArrow: true,
        arrowSize: 8.0,
        label: 'test edge',
      );

      final json = style.toJson();
      final restored = EdgeStyle.fromJson(json);

      expect(restored.color, const Color(0xFF123456));
      expect(restored.thickness, 3.5);
      expect(restored.edgeType, EdgeType.smoothStep);
      expect(restored.animated, false);
      expect(restored.dashPattern, [8.0]);
      expect(restored.showArrow, true);
      expect(restored.arrowSize, 8.0);
      expect(restored.label, 'test edge');
    });

    test('fromJson defaults for missing optional fields', () {
      final json = {
        'color': const Color(0xFF000000).toARGB32(),
        'thickness': 1.0,
        'edgeType': 'bezier',
      };
      final style = EdgeStyle.fromJson(json);
      expect(style.animated, false);
      expect(style.dashPattern, isEmpty);
      expect(style.arrowSize, 8.0);
      expect(style.showArrow, true);
      expect(style.label, isNull);
    });

    test('copyWith replaces specified fields only', () {
      const style = EdgeStyle();
      final copied = style.copyWith(
        color: const Color(0xFFFFFFFF),
        thickness: 5.0,
        animated: false,
      );

      expect(copied.color, const Color(0xFFFFFFFF));
      expect(copied.thickness, 5.0);
      expect(copied.animated, false);
      expect(copied.edgeType, style.edgeType);
      expect(copied.showArrow, style.showArrow);
    });
  });
}
