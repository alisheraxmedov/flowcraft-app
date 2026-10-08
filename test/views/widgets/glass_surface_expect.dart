import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the [GlassIsland] around [inside] is the mockup's popover surface:
/// glass-strong fill, 1px glass border, [radius], the island shadow and a
/// real backdrop blur.
void expectGlassSurface(
  WidgetTester tester,
  Finder inside, {
  required double radius,
  FcTokens tokens = FcTokens.light,
}) {
  final island = find.ancestor(of: inside, matching: find.byType(GlassIsland));
  final widget = tester.widget<GlassIsland>(island.first);
  expect(widget.strong, isTrue, reason: 'glass-strong, not glass');
  expect(widget.radius, radius);

  final decorations = [
    for (final box in tester.widgetList<DecoratedBox>(
      find.descendant(of: island.first, matching: find.byType(DecoratedBox)),
    ))
      if (box.decoration is BoxDecoration) box.decoration as BoxDecoration,
  ];
  final fill = decorations.firstWhere((d) => d.color != null);
  expect(fill.color, tokens.glassStrong);
  expect(fill.border, Border.all(color: tokens.glassBorder));
  expect(fill.borderRadius, BorderRadius.circular(radius));
  expect(
    decorations.firstWhere((d) => d.boxShadow != null).boxShadow,
    tokens.shadow,
  );
  expect(
    find.descendant(of: island.first, matching: find.byType(BackdropFilter)),
    findsOneWidget,
  );
}
