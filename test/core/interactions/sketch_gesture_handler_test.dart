import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

/// Regression coverage for the interaction layer — specifically the eraser
/// tool, which the user reported as "stopped working" after the
/// `SketchHitTest` stroke-hit consolidation. There was previously zero test
/// coverage under `test/core/interactions/`, so a subtle regression there
/// would not have been caught by the rest of the suite.
void main() {
  testWidgets(
      'eraser tool removes the element under the pointer on pointer down',
      (tester) async {
    final controller = SketchController(currentTool: SketchTool.eraser);
    addTearDown(controller.dispose);

    // A filled rectangle so a tap anywhere in its interior hits it,
    // independent of stroke-hit tolerance edge cases.
    final rect = SketchRectangle.create(
      id: 'erase-me',
      rect: const Rect.fromLTWH(0, 0, 100, 100),
      style: const SketchStyle(
        fillStyle: FillStyle.solid,
        fillColor: Color(0xFF000000),
      ),
    );
    controller.add(rect);
    expect(controller.elements, hasLength(1));

    final interaction = SketchInteractionState();
    addTearDown(interaction.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SketchGestureHandler(
          controller: controller,
          interaction: interaction,
          viewportProvider: () => const FlowViewport(),
          child: const SizedBox.expand(),
        ),
      ),
    );

    // The gesture handler fills the whole test surface at offset zero and
    // the default viewport has zero pan / 1.0 zoom, so screen == canvas
    // coordinates. Tap the interior of the rectangle (canvas 50,50).
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(controller.elements, isEmpty);
  });
}
