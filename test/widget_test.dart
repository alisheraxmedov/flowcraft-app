import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

import 'package:flowcraft/app.dart';

void main() {
  testWidgets('whiteboard app builds and renders the sketch toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      // Port 0 — building the app really does start the MCP control
      // server, and `flutter test` runs files in parallel, so anything
      // that pumps the app must let the OS pick a free port instead of
      // racing every other file (and the developer's own running
      // FlowCraft window) for 5199.
      ProviderScope(
        overrides: [mcpServerPortProvider.overrideWithValue(0)],
        child: const FlowCraftWhiteboardApp(),
      ),
    );

    // The app now opens on SplashView first. Pump past its minimum display
    // duration/safety timeout and the AnimatedSwitcher hand-off to reach
    // the whiteboard — fixed-duration pumps, not pumpAndSettle, since the
    // splash's indeterminate CircularProgressIndicator never lets a frame
    // settle on its own.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(WhiteboardCanvas), findsOneWidget);
    expect(find.byType(SketchToolbarRich), findsOneWidget);
  });
}
