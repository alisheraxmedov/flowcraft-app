import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/flowcraft.dart';

/// Stands in for the real view model so these tests never bind a socket at
/// all: [McpViewModel.build] starts a real control server, which would make
/// what the card renders depend on a live port. Overriding [build] (and the
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

  Future<void> pumpCard(WidgetTester tester, McpServerStatus status) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpViewModelProvider.overrideWith(() => _FakeMcpViewModel(status)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: McpCard())),
        ),
      ),
    );
  }

  const running = McpServerStatus.running(port: 5199, token: 'test-token');
  const failed = McpServerStatus.failed(
    'Port 5199 is unavailable: Address already in use',
  );

  testWidgets('shows the live endpoint while the server is running', (
    tester,
  ) async {
    await pumpCard(tester, running);

    expect(find.text('ON'), findsOneWidget);
    expect(find.text('Status: Online'), findsOneWidget);
    expect(find.text('http://127.0.0.1:5199/mcp'), findsOneWidget);
    expect(find.text('Copy connect'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('names the build in its footer, whatever the server state', (
    tester,
  ) async {
    // The same string the MCP handshake and `/health` report; a bug report
    // filed from a screenshot names the build it came from.
    for (final status in [running, failed, const McpServerStatus.off()]) {
      await pumpCard(tester, status);
      expect(find.text('FlowCraft v$appVersion'), findsOneWidget);
    }
  });

  testWidgets('hides the connection details while the server is off', (
    tester,
  ) async {
    await pumpCard(tester, const McpServerStatus.off());

    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Status: Offline'), findsOneWidget);
    expect(find.textContaining('/mcp'), findsNothing);
    expect(find.text('Copy connect'), findsNothing);
  });

  testWidgets('promises nothing while the server is still starting', (
    tester,
  ) async {
    await pumpCard(tester, const McpServerStatus.starting());

    expect(find.text('STARTING'), findsOneWidget);
    expect(find.text('Status: Starting…'), findsOneWidget);
    expect(find.text('Status: Online'), findsNothing);
    expect(find.textContaining('/mcp'), findsNothing);
    expect(find.text('Copy connect'), findsNothing);
  });

  testWidgets('a failed start shows the reason, not a dead endpoint', (
    tester,
  ) async {
    await pumpCard(tester, failed);

    expect(find.text('ERROR'), findsOneWidget);
    expect(find.text('Status: Failed to start'), findsOneWidget);
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

  testWidgets('the failed state is coloured with the error token', (
    tester,
  ) async {
    await pumpCard(tester, failed);

    final scheme = AppTheme.dark().colorScheme;
    final badge = tester.widget<Text>(find.text('ERROR'));
    expect(badge.style?.color, scheme.error);
    expect(
      tester
          .widget<Text>(
            find.text('Port 5199 is unavailable: Address already in use'),
          )
          .style
          ?.color,
      scheme.onErrorContainer,
    );
  });

  testWidgets('Retry asks the view model to start again', (tester) async {
    await pumpCard(tester, failed);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.text('Status: Starting…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('copies the connect command and confirms it', (tester) async {
    await pumpCard(tester, running);

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
    // A platform-channel refusal used to be an unhandled async error with
    // no snackbar: Copy did nothing and said nothing.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'denied', message: 'no clipboard');
          }
          return null;
        });
    await pumpCard(tester, running);

    await tester.tap(find.text('Copy connect'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Could not copy'), findsOneWidget);
    expect(find.text('Copied the connect command'), findsNothing);
  });

  testWidgets('Setup opens per-CLI config for all three CLIs', (tester) async {
    await pumpCard(tester, running);

    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();

    expect(find.text('Connect an AI CLI'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('Codex CLI'), findsOneWidget);
    expect(find.text('Gemini CLI'), findsOneWidget);
    // The snippets must carry this machine's real token, not a placeholder.
    expect(find.textContaining('test-token'), findsWidgets);
  });

  testWidgets('the switch drives the view model', (tester) async {
    await pumpCard(tester, running);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('Status: Offline'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('the switch sits off while a start has failed', (tester) async {
    await pumpCard(tester, failed);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
