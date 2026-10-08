import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

void main() {
  test('mockup icon count matches the 41 distinct mockup SVGs', () {
    // 46 <svg> in C-Board + C-Parts, minus the board diagram, minus 4
    // byte-identical repeats (square, pencil, 2x copy) = 41. A missed icon
    // changes this number.
    expect(FcIcons.mockup, hasLength(41));
    expect(FcIcons.lucide, hasLength(11));
    expect(FcIcons.all, hasLength(52));
    expect(FcIcons.all.map((i) => i.name).toSet(), hasLength(52));
  });

  test('every icon yields ink inside its viewBox (± stroke)', () {
    for (final icon in FcIcons.all) {
      final paths = fcIconPaths(icon);
      expect(paths, isNotEmpty, reason: icon.name);
      final box = Rect.fromLTWH(
        0,
        0,
        icon.width,
        icon.height,
      ).inflate(icon.strokeWidth / 2 + 0.01);
      for (final p in paths) {
        final b = p.getBounds();
        expect(
          b.isEmpty && b.width == 0 && b.height == 0,
          isFalse,
          reason: icon.name,
        );
        expect(
          box.contains(b.topLeft) && box.contains(b.bottomRight),
          isTrue,
          reason: '${icon.name} $b outside $box',
        );
      }
    }
  });

  test('arc-heavy icons parse to real geometry', () {
    for (final icon in [FcIcons.eraser, FcIcons.hand]) {
      final b = fcIconPaths(
        icon,
      ).map((p) => p.getBounds()).reduce((a, b) => a.expandToInclude(b));
      expect(b.width, greaterThan(15), reason: icon.name);
      expect(b.height, greaterThan(15), reason: icon.name);
    }
  });

  test('dashed stroke preview is split into several segments', () {
    final p = fcIconPaths(FcIcons.strokeDashed).single;
    expect(p.computeMetrics().length, 3);
  });

  testWidgets('glyph lays out at size and paints in the given colour', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const FcIconGlyph(
              FcIcons.square,
              size: 40,
              color: Color(0xFFFF0000),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FcIconGlyph)), const Size(40, 40));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = (await image.toByteData())!;
      // Left edge of the square: x = 3/24*40 = 5px, mid-height.
      final i = (20 * 40 + 5) * 4;
      expect(data.getUint8(i), 255, reason: 'red channel');
      expect(data.getUint8(i + 3), greaterThan(100), reason: 'alpha');
      // Centre is empty (stroke only, no fill).
      expect(data.getUint8((20 * 40 + 20) * 4 + 3), 0);
    });
  });

  testWidgets('semantics only with a label; theme colour is the default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(color: Color(0xFF00FF00)),
          child: Column(
            children: [
              FcIconGlyph(FcIcons.plus),
              FcIconGlyph(FcIcons.plus, semanticLabel: 'Add'),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Add'), findsOneWidget);
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });
}
