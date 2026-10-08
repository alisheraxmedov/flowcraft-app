import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/rendering/arrow_head.dart';
import 'package:flowcraft/models/sketch_element.dart';

void main() {
  const from = Offset(0, 0);
  const to = Offset(100, 0);

  for (final style in ArrowheadStyle.values) {
    test('$style path', () {
      final path = ArrowHead.pathFor(style, from, to, 10);
      expect(path.computeMetrics().isEmpty, style == ArrowheadStyle.none);
      if (style == ArrowheadStyle.none) return;
      // Glyphs stay near the tip, inside the envelope bounds reserve.
      final bounds = path.getBounds();
      expect(bounds.right, lessThanOrEqualTo(to.dx + 1e-9));
      expect(bounds.left, greaterThanOrEqualTo(to.dx - 13.0 - 1e-9));
      expect(bounds.height, lessThanOrEqualTo(10 * 0.96 + 1e-9));
    });
  }

  test('zero-length shaft does not produce NaN', () {
    final b = ArrowHead.pathFor(ArrowheadStyle.many, to, to, 10).getBounds();
    expect(b.left.isNaN, isFalse);
  });
}
