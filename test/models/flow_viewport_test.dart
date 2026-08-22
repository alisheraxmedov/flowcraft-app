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

    test('copyWith works', () {
      const vp = FlowViewport(offset: Offset.zero, zoom: 1.0);
      final copied = vp.copyWith(zoom: 2.0);

      expect(copied.offset, Offset.zero);
      expect(copied.zoom, 2.0);
    });

    test('copyWith clamps zoom into the current range', () {
      const vp = FlowViewport(minZoom: 0.1, maxZoom: 4.0);
      expect(vp.copyWith(zoom: 9.0).zoom, 4.0);
      expect(vp.copyWith(zoom: 0.0).zoom, 0.1);
    });

    test('zoom is clamped when min/max change in the same copyWith', () {
      // Used to clamp against the *old* limits, so a zoom that was legal
      // under them sailed through the new, narrower ones.
      const vp = FlowViewport(minZoom: 0.1, maxZoom: 4.0, zoom: 1.0);
      final narrowed = vp.copyWith(zoom: 3.0, minZoom: 0.5, maxZoom: 2.0);
      expect(narrowed.zoom, 2.0);
      expect(narrowed.minZoom, 0.5);
      expect(narrowed.maxZoom, 2.0);

      final raised = vp.copyWith(zoom: 0.2, minZoom: 0.5);
      expect(raised.zoom, 0.5);
    });

    test('narrowing the limits alone pulls an existing zoom into them', () {
      const vp = FlowViewport(zoom: 3.0);
      expect(vp.copyWith(maxZoom: 2.0).zoom, 2.0);
      expect(vp.copyWith(minZoom: 3.5).zoom, 3.5);
    });
  });
}
