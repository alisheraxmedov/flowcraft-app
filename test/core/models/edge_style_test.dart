import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('EdgeStyle', () {
    test('supports value equality', () {
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
        dashPattern: [5.0, 5.0], // different
      );

      expect(style1, style2);
      expect(style1.hashCode, style2.hashCode);
      expect(style1, isNot(style3));
    });

    test('toJson and fromJson work correctly', () {
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

    test('copyWith works correctly', () {
      const style = EdgeStyle();
      final copied = style.copyWith(
        color: const Color(0xFFFFFFFF),
        thickness: 5.0,
      );

      expect(copied.color, const Color(0xFFFFFFFF));
      expect(copied.thickness, 5.0);
      expect(copied.edgeType, style.edgeType); // unchanged
    });
  });
}
