import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowViewport', () {
    test('equality check', () {
      const v1 = FlowViewport(offset: Offset(10, 20), zoom: 1.5);
      const v2 = FlowViewport(offset: Offset(10, 20), zoom: 1.5);
      const v3 = FlowViewport(offset: Offset(10, 21), zoom: 1.5);

      expect(v1, v2);
      expect(v1.hashCode, v2.hashCode);
      expect(v1, isNot(v3));
    });

    test('serialization round-trip', () {
      const vp = FlowViewport(
        offset: Offset(150, -50),
        zoom: 2.5,
        minZoom: 0.1,
        maxZoom: 5.0,
      );

      final json = vp.toJson();
      final restored = FlowViewport.fromJson(json);

      expect(restored.offset, const Offset(150, -50));
      expect(restored.zoom, 2.5);
      expect(restored.minZoom, 0.1);
      expect(restored.maxZoom, 5.0);
    });

    test('copyWith works', () {
      const vp = FlowViewport(offset: Offset.zero, zoom: 1.0);
      final copied = vp.copyWith(zoom: 2.0);

      expect(copied.offset, Offset.zero);
      expect(copied.zoom, 2.0);
    });
  });
}
