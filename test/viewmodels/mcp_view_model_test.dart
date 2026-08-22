import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  /// Every container here starts a *real* control server, so nothing may
  /// touch the app's fixed 5199: `flutter test` runs files in parallel, and
  /// a developer running this suite almost certainly has FlowCraft itself
  /// open on that port. Port 0 lets the OS hand out a free one per test.
  ProviderContainer makeContainer({int port = 0}) {
    final container = ProviderContainer(
      overrides: [mcpServerPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Silences the expected "control server start failed" line for tests
  /// that are *supposed* to fail to bind, so a genuine failure still
  /// stands out in CI output.
  void muteDebugPrint() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  }

  /// Binds a port and holds it for the duration of the test, so the server
  /// under test provably can't have it. Owning the port outright is the
  /// point: a test that squats on a *well-known* port could pass either
  /// because it blocked the bind or because something else on the machine
  /// did, and only one of those is the thing being tested.
  Future<int> occupyAPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(socket.close);
    return socket.port;
  }

  group('McpServerStatus', () {
    test('an off server has nothing to connect to', () {
      const status = McpServerStatus.off();

      expect(status.isOn, isFalse);
      expect(status.isRunning, isFalse);
      expect(status.endpoint, isNull);
      expect(status.connectCommand, isNull);
    });

    test('a starting server reads as on but not yet connectable', () {
      const status = McpServerStatus.starting();

      expect(status.isOn, isTrue);
      expect(status.isRunning, isFalse);
      expect(status.endpoint, isNull);
      expect(status.connectCommand, isNull);
    });

    test('builds the loopback endpoint from whatever port was bound', () {
      // Deliberately not 5199: the endpoint has to follow the real port,
      // which is exactly what makes port 0 usable everywhere else here.
      const status = McpServerStatus.running(port: 61234, token: 'abc');

      expect(status.endpoint, 'http://127.0.0.1:61234/mcp');
    });

    test('builds the Claude Code connect command', () {
      // 5199 here is the *documented* default from the README, not a
      // socket — this status object never binds anything.
      const status = McpServerStatus.running(port: 5199, token: 'abc');

      expect(
        status.connectCommand,
        'claude mcp add --transport http flowcraft '
        'http://127.0.0.1:5199/mcp --header "X-Flowcraft-Token: abc"',
      );
    });

    test('a failed server carries a reason and no connect command', () {
      const status = McpServerStatus.failed('Port 5199 is unavailable');

      expect(status.hasFailed, isTrue);
      // The switch reports whether the server is serving; a failed start
      // must never settle in the "on" position.
      expect(status.isOn, isFalse);
      expect(status.error, 'Port 5199 is unavailable');
      expect(status.endpoint, isNull);
      expect(status.connectCommand, isNull);
    });

    test('compares by value', () {
      const a = McpServerStatus.running(port: 61234, token: 'abc');
      const b = McpServerStatus.running(port: 61234, token: 'abc');
      const c = McpServerStatus.running(port: 61235, token: 'abc');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(const McpServerStatus.failed('x'),
          isNot(const McpServerStatus.failed('y')));
    });
  });

  group('McpViewModel', () {
    test('starts out starting, not claiming to be online', () {
      final container = makeContainer();

      final status = container.read(mcpViewModelProvider);
      expect(status.isStarting, isTrue);
      expect(status.isRunning, isFalse);
      expect(status.endpoint, isNull);
    });

    test('a successful start publishes the port it actually bound',
        () async {
      final container = makeContainer();
      final notifier = container.read(mcpViewModelProvider.notifier);

      await notifier.ready;

      final status = container.read(mcpViewModelProvider);
      expect(status.isRunning, isTrue);
      // Port 0 was requested; the status must report the port the OS
      // handed back, never the number that was asked for.
      expect(status.port, isNotNull);
      expect(status.port, isNot(0));
      expect(status.token, isNotNull);
      expect(status.endpoint, 'http://127.0.0.1:${status.port}/mcp');
      expect(status.connectCommand, contains('${status.port}'));
    });

    test('toggle switches between on and off', () {
      final container = makeContainer();
      final notifier = container.read(mcpViewModelProvider.notifier);

      notifier.toggle();
      expect(container.read(mcpViewModelProvider).isOn, isFalse);

      notifier.toggle();
      expect(container.read(mcpViewModelProvider).isOn, isTrue);
    });

    test('toggling notifies listeners', () {
      final container = makeContainer();

      final seen = <McpServerState>[];
      container.listen<McpServerStatus>(
        mcpViewModelProvider,
        (previous, next) => seen.add(next.state),
        fireImmediately: true,
      );

      container.read(mcpViewModelProvider.notifier).toggle();

      expect(seen, [McpServerState.starting, McpServerState.off]);
    });

    test('turning the server off drops the connection details', () {
      final container = makeContainer();

      container.read(mcpViewModelProvider.notifier).toggle();
      final status = container.read(mcpViewModelProvider);

      expect(status.isOn, isFalse);
      expect(status.endpoint, isNull);
      expect(status.token, isNull);
    });

    test('a port already in use fails loudly instead of faking success',
        () async {
      muteDebugPrint();
      final taken = await occupyAPort();

      final container = makeContainer(port: taken);
      await container.read(mcpViewModelProvider.notifier).ready;

      final status = container.read(mcpViewModelProvider);
      expect(status.hasFailed, isTrue);
      expect(status.error, contains('$taken'));
      expect(status.error, contains('unavailable'));
      expect(status.isOn, isFalse);
      expect(status.endpoint, isNull);
      expect(status.connectCommand, isNull);
    });

    test('retry after a failure starts the server once the port frees up',
        () async {
      muteDebugPrint();
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;

      final container = makeContainer(port: port);
      final notifier = container.read(mcpViewModelProvider.notifier);
      await notifier.ready;
      expect(container.read(mcpViewModelProvider).hasFailed, isTrue);

      // The usual real-world fix: whatever was squatting goes away.
      await socket.close();
      notifier.retry();
      // `ready` only covers the first attempt; `settled` is the retry's own
      // queued transition.
      await notifier.settled;

      final status = container.read(mcpViewModelProvider);
      expect(status.isRunning, isTrue);
      expect(status.port, port);
      expect(status.endpoint, 'http://127.0.0.1:$port/mcp');
    });

    test('ready resolves even when the server cannot start', () async {
      muteDebugPrint();
      final taken = await occupyAPort();

      final container = makeContainer(port: taken);

      // The splash screen awaits this; it must complete rather than throw,
      // or a busy port would strand the user on the splash screen.
      await expectLater(
        container.read(mcpViewModelProvider.notifier).ready,
        completes,
      );
    });
  });
}
