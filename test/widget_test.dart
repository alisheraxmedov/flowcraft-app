import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

import 'package:flowcraft/app.dart';

void main() {
  testWidgets('whiteboard app builds and renders the sketch toolbar',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FlowCraftWhiteboardApp()),
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
