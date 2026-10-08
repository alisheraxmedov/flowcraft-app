import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/services/app_version.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/views/widgets/mcp_setup_dialog.dart';
import 'package:flowcraft/views/widgets/agents_popover.dart';
import 'package:flowcraft/views/widgets/glass/fc_switch.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flowcraft/viewmodels/canvas_preferences.dart';

/// Stands in for the real view model so these tests never bind a socket at
/// all: [McpViewModel.build] starts a real control server, which would make
/// what the popover renders depend on a live port. Overriding [build] (and the
/// two transitions, which would otherwise reach for the server that build
/// never created) keeps every state below pure data.
class _FakeMcpViewModel extends McpViewModel {
  _FakeMcpViewModel(this.initial);

  final McpServerStatus initial;

  @override
  McpServerStatus build() => initial;

  @override
  void toggle() => state = state.isOn
      ? const McpServerStatus.off()
      : const McpServerStatus.starting();

  @override
  void retry() => state = const McpServerStatus.starting();
}

void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpChip(WidgetTester tester, McpServerStatus status) async {
    // Unmount first so a repeat call in one test starts with a closed popover.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpViewModelProvider.overrideWith(() => _FakeMcpViewModel(status)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: AgentsChip())),
        ),
      ),
    );
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();
  }

  const running = McpServerStatus.running(port: 5199, token: 'test-token');
  const failed = McpServerStatus.failed(
    'Port 5199 is unavailable: Address already in use',
  );

  testWidgets('shows the live endpoint while the server is running', (
    tester,
  ) async {
    await pumpChip(tester, running);

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('http://127.0.0.1:5199/mcp'), findsOneWidget);
    expect(find.text('Copy connect'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('the popover stays closed until the chip is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpViewModelProvider.overrideWith(() => _FakeMcpViewModel(running)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: AgentsChip())),
        ),
      ),
    );
    expect(find.text('MCP Server'), findsNothing);
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();
    expect(find.text('MCP Server'), findsOneWidget);
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();
    expect(find.text('MCP Server'), findsNothing);
  });

  testWidgets('names the build in its footer, whatever the server state', (
    tester,
  ) async {
    for (final status in [running, failed, const McpServerStatus.off()]) {
      await pumpChip(tester, status);
      expect(find.text('FlowCraft v$appVersion'), findsOneWidget);
    }
  });

  testWidgets('hides the connection details while the server is off', (
    tester,
  ) async {
    await pumpChip(tester, const McpServerStatus.off());

    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('/mcp'), findsNothing);
    expect(find.text('Copy connect'), findsNothing);
  });

  testWidgets('promises nothing while the server is still starting', (
    tester,
  ) async {
    await pumpChip(tester, const McpServerStatus.starting());

    expect(find.text('Starting…'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
    expect(find.textContaining('/mcp'), findsNothing);
    expect(find.text('Copy connect'), findsNothing);
  });

  testWidgets('a failed start shows the reason, not a dead endpoint', (
    tester,
  ) async {
    await pumpChip(tester, failed);

    expect(find.text('Failed to start'), findsOneWidget);
    expect(
      find.text('Port 5199 is unavailable: Address already in use'),
      findsOneWidget,
    );
    // The whole point: nothing copyable and nothing to connect to.
    expect(find.textContaining('/mcp'), findsNothing);
    expect(find.text('Copy connect'), findsNothing);
    expect(find.text('Setup'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the failed state is coloured with the danger token', (
    tester,
  ) async {
    await pumpChip(tester, failed);

    final t = FcTokens.dark;
    expect(
      tester.widget<Text>(find.text('Failed to start')).style?.color,
      t.danger,
    );
    expect(
      tester
          .widget<Text>(
            find.text('Port 5199 is unavailable: Address already in use'),
          )
          .style
          ?.color,
      t.danger,
    );
  });

  testWidgets('Retry asks the view model to start again', (tester) async {
    await pumpChip(tester, failed);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.text('Starting…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('copies the connect command and confirms it', (tester) async {
    await pumpChip(tester, running);

    await tester.tap(find.text('Copy connect'));
    await tester.pump();

    final copy = platformCalls.singleWhere(
      (c) => c.method == 'Clipboard.setData',
    );
    expect(
      (copy.arguments as Map)['text'],
      'claude mcp add --transport http flowcraft '
      'http://127.0.0.1:5199/mcp --header "X-Flowcraft-Token: test-token"',
    );
    expect(find.text('Copied the connect command'), findsOneWidget);
  });

  testWidgets('a refused clipboard is reported, not swallowed', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'denied', message: 'no clipboard');
          }
          return null;
        });
    await pumpChip(tester, running);

    await tester.tap(find.text('Copy connect'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Could not copy'), findsOneWidget);
    expect(find.text('Copied the connect command'), findsNothing);
  });

  testWidgets('Setup closes the popover and opens the Connect dialog', (
    tester,
  ) async {
    await pumpChip(tester, running);

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();

    expect(find.text('Connect an AI CLI'), findsOneWidget);
    expect(find.text('MCP Server'), findsNothing);
  });

  testWidgets('the MCP switch drives the view model', (tester) async {
    await pumpChip(tester, running);

    expect(tester.widget<FcSwitch>(find.byType(FcSwitch).first).value, isTrue);

    await tester.tap(find.byType(FcSwitch).first);
    await tester.pump();

    expect(find.text('Offline'), findsOneWidget);
    expect(tester.widget<FcSwitch>(find.byType(FcSwitch).first).value, isFalse);
  });

  testWidgets('the switch sits off while a start has failed', (tester) async {
    await pumpChip(tester, failed);

    expect(tester.widget<FcSwitch>(find.byType(FcSwitch).first).value, isFalse);
  });

  testWidgets('Animate agent drawing switch toggles the provider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        mcpViewModelProvider.overrideWith(
          () => _FakeMcpViewModel(const McpServerStatus.off()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: AgentsChip())),
        ),
      ),
    );
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();
    expect(find.text('Animate agent drawing'), findsOneWidget);
    expect(container.read(animateAgentDrawingProvider), isTrue);

    await tester.tap(find.byType(FcSwitch).last);
    await tester.pump();

    expect(container.read(animateAgentDrawingProvider), isFalse);
  });

  group('Connect dialog', () {
    Future<void> pumpDialog(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: McpSetupDialog(status: running)),
      ),
    );

    testWidgets('shows four tabs and the active snippet carries the token', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(find.text('Connect an AI CLI'), findsOneWidget);
      for (final tab in [
        'Claude Code',
        'Claude JSON',
        'Codex CLI',
        'Gemini CLI',
      ]) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.textContaining('claude mcp add'), findsOneWidget);
      expect(find.textContaining('test-token'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Done is right-aligned and compact', (tester) async {
      await pumpDialog(tester);
      final done = tester.getRect(find.byKey(const ValueKey('mcp_done')));
      final card = tester.getRect(find.byType(GlassIsland));
      expect(done.height, 36);
      expect(done.width, lessThan(100));
      // 20 padding + the 1px border, on each side.
      expect(done.right, closeTo(card.right - 21, 0.5));
    });

    testWidgets('tapping a tab swaps the snippet', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Codex CLI'));
      await tester.pump();

      expect(find.textContaining('claude mcp add'), findsNothing);
      expect(find.textContaining('[mcp_servers.flowcraft]'), findsOneWidget);
      expect(find.textContaining('test-token'), findsOneWidget);

      await tester.tap(find.text('Gemini CLI'));
      await tester.pump();
      expect(find.textContaining('httpUrl'), findsOneWidget);
    });

    testWidgets('Copy copies the active snippet', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Codex CLI'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Copy'));
      await tester.pump();

      final copy = platformCalls.singleWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map)['text'],
        contains('[mcp_servers.flowcraft]'),
      );
    });
  });
}
