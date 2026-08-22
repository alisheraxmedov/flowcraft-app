import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';

import '../support/fake_project_repository.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        // Port 0 — the splash's whole job is awaiting the real MCP control
        // server, and `flutter test` runs files in parallel, so it must bind
        // a free port the OS picks rather than race for the fixed 5199.
        mcpServerPortProvider.overrideWithValue(0),
        // The splash also awaits the project restore. A `dart:io`-backed
        // repository never resolves inside `testWidgets`' fake-async zone,
        // so the hand-off would only ever happen via the ready timeout.
        projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: child),
    );
  }

  testWidgets('splash shows the logo and app name before startup finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SplashView(
          minDisplayDuration: Duration(milliseconds: 50),
          readyTimeout: Duration(milliseconds: 200),
        ),
      ),
    );

    // First frame only, before any timer has fired: splash content is up,
    // the whiteboard hasn't been built yet.
    expect(find.text('FlowCraft'), findsOneWidget);
    expect(find.text('Loading workspace…'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(WhiteboardCanvas), findsNothing);

    // Drain the pending startup/entrance timers before the test ends —
    // otherwise the test binding's "no pending timers" invariant trips.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('splash hands off to the whiteboard once startup settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SplashView(
          minDisplayDuration: Duration(milliseconds: 10),
          readyTimeout: Duration(milliseconds: 100),
        ),
      ),
    );

    // Deliberately fixed-duration `pump`s, not `pumpAndSettle` — the splash
    // shows an indeterminate `CircularProgressIndicator`, which schedules a
    // new frame forever and would make `pumpAndSettle` hang/time out.
    // First jump clears both the minimum display duration and the (short,
    // test-only) ready timeout; the second clears the AnimatedSwitcher
    // cross-fade hand-off to WhiteboardView.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(WhiteboardCanvas), findsOneWidget);
    expect(find.byType(SketchToolbarRich), findsOneWidget);
    // The splash's own status line, not its wordmark — the whiteboard's top
    // bar also renders "FlowCraft", so that text alone can't tell the two
    // screens apart.
    expect(find.text('Loading workspace…'), findsNothing);
  });
}
