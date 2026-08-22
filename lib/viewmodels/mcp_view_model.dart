import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/services/app_control.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// The conditions the MCP server can actually be in.
///
/// [starting] and [failed] exist because binding a socket is neither
/// instant nor guaranteed: a stale FlowCraft instance holding port 5199 is
/// the common case, and collapsing that into "on" would leave the card
/// showing a confident green light over an endpoint nobody is serving.
enum McpServerState { off, starting, running, failed }

/// Everything the UI knows about the app's built-in MCP server: which of
/// the four states it's in, plus the details that only exist in some of
/// them.
///
/// The unnamed constructor is private and every state has its own factory,
/// so the invalid combinations can't be built: [running] always carries a
/// port and token, [failed] always carries a reason, and neither [off] nor
/// [starting] can carry a connectable endpoint.
@immutable
class McpServerStatus {
  const McpServerStatus._({
    required this.state,
    this.port,
    this.token,
    this.error,
  });

  const McpServerStatus.off() : this._(state: McpServerState.off);

  const McpServerStatus.starting() : this._(state: McpServerState.starting);

  const McpServerStatus.running({required int port, required String token})
      : this._(state: McpServerState.running, port: port, token: token);

  /// [reason] is rendered straight into the card, so it must be one short
  /// human sentence — see [AppControlStartException].
  const McpServerStatus.failed(String reason)
      : this._(state: McpServerState.failed, error: reason);

  final McpServerState state;

  /// Loopback port the server bound. Only ever set while [isRunning].
  final int? port;

  /// Shared secret every MCP request must carry. Only ever set while
  /// [isRunning].
  final String? token;

  /// Why the server isn't running. Only ever set while [hasFailed].
  final String? error;

  bool get isRunning => state == McpServerState.running;
  bool get isStarting => state == McpServerState.starting;
  bool get hasFailed => state == McpServerState.failed;

  /// Where the toggle sits. A failed start reads as *off* — the switch
  /// reports whether the server is serving, and the error line next to it
  /// explains why it isn't.
  bool get isOn => isRunning || isStarting;

  /// Where to point an MCP client. Null unless the socket is really bound.
  String? get endpoint => port == null ? null : 'http://127.0.0.1:$port/mcp';

  /// One-liner that registers the running app with Claude Code. Null
  /// whenever there's nothing to connect to — a command that points at a
  /// dead port is worse than no command at all.
  String? get connectCommand {
    final url = endpoint;
    if (url == null || token == null) return null;
    return 'claude mcp add --transport http flowcraft $url '
        '--header "X-Flowcraft-Token: $token"';
  }

  @override
  bool operator ==(Object other) =>
      other is McpServerStatus &&
      other.state == state &&
      other.port == port &&
      other.token == token &&
      other.error == error;

  @override
  int get hashCode => Object.hash(state, port, token, error);
}

/// The port the built-in MCP server binds.
///
/// Fixed at 5199 in the app on purpose — users paste the endpoint into a
/// CLI config once and it has to keep working across restarts (see
/// `CLAUDE.md`). It's a provider rather than a constant purely so tests can
/// override it with **0** and let the OS hand out a free port: `flutter
/// test` runs test files in parallel, so any two that pump the app would
/// otherwise fight over the same socket — and lose to a real FlowCraft
/// window, which is the normal state of a developer's machine here.
final mcpServerPortProvider = Provider<int>((ref) => 5199);

/// Owns the [AppControlServer] for the lifetime of the app: starts it on
/// first read, stops it on dispose, and starts/stops it again on [toggle].
class McpViewModel extends Notifier<McpServerStatus> {
  late final AppControlServer _server;

  /// Resolves once the *initial* startup attempt triggered from [build] has
  /// finished — whether it bound a port or failed. Callers (e.g. the splash
  /// screen) can `await` this for a genuine readiness signal instead of
  /// guessing with a fixed delay. It never completes with an error: a
  /// control server that won't bind must not take the whiteboard down with
  /// it, so the failure lands in [state] instead.
  late final Future<void> ready;

  /// Serializes start/stop so a fast off→on flip can't have `start()`
  /// racing the `stop()` before it — which would fail to bind and report a
  /// busy port the user never actually had.
  Future<void> _pending = Future<void>.value();

  /// Counts every start/stop the user has asked for. A transition publishes
  /// its outcome only if it is still the newest request: the queue runs
  /// them in order, so a fast on→off flip used to have the *start* land
  /// first and flash "running" — endpoint and all — for as long as the
  /// `stop()` behind it took, on a switch the user had already turned off.
  int _intent = 0;

  /// The transition currently in flight, or an already-completed future
  /// when idle. [toggle] and [retry] are fire-and-forget because the UI
  /// calls them from a callback; tests need something to await.
  @visibleForTesting
  Future<void> get settled => _pending;

  @override
  McpServerStatus build() {
    // `read`, not `watch` — this only needs the controller instance once,
    // not a rebuild every time the canvas changes.
    final controller = ref.read(sketchControllerProvider);
    _server = AppControlServer(
      controller: controller,
      port: ref.read(mcpServerPortProvider),
    );
    ready = _apply(start: true);
    // Queued, not called directly: disposing while the initial start is
    // still in flight would otherwise stop a server that hasn't bound yet
    // — a no-op — and the socket would then come up with nobody left to
    // close it, holding the port for the rest of the process.
    ref.onDispose(() {
      _pending = _pending.then((_) => _server.stop());
    });
    return const McpServerStatus.starting();
  }

  void toggle() {
    final starting = !state.isOn;
    // Move the switch now and reconcile when the socket work lands:
    // binding is asynchronous, but a toggle that lags a frame behind the
    // click feels broken. `starting` is an honest optimism — it promises
    // the attempt, not the outcome.
    state = starting
        ? const McpServerStatus.starting()
        : const McpServerStatus.off();
    unawaited(_apply(start: starting));
  }

  /// Re-attempts a start after a failure. Separate from [toggle] only for
  /// the card's Retry button to read clearly; a failed server counts as
  /// off, so toggling it does the same thing.
  void retry() {
    if (state.isStarting) return;
    state = const McpServerStatus.starting();
    unawaited(_apply(start: true));
  }

  Future<void> _apply({required bool start}) {
    final intent = ++_intent;
    // The `catchError` keeps the chain healthy: anything escaping [_run]
    // would otherwise leave `_pending` in a failed state, and every later
    // toggle would short-circuit on it for the rest of the session.
    _pending = _pending
        .then((_) => _run(start: start, intent: intent))
        .catchError(
          (Object e) =>
              debugPrint('FlowCraft control server transition failed: $e'),
        );
    return _pending;
  }

  Future<void> _run({required bool start, required int intent}) async {
    try {
      await (start ? _server.start() : _server.stop());
    } catch (e) {
      debugPrint(
        'FlowCraft control server ${start ? 'start' : 'stop'} '
        'failed: $e',
      );
      // A failed *stop* still leaves the user where they asked to be
      // (switch off, nothing to connect to), and offering "retry" for it
      // would only try to start the server again. Only a failed start
      // becomes a visible error state.
      if (!_mayPublish(intent)) return;
      state = start
          ? McpServerStatus.failed('$e')
          : const McpServerStatus.off();
      return;
    }
    if (!_mayPublish(intent)) return;
    final port = _server.boundPort;
    final token = _server.token;
    if (!start) {
      state = const McpServerStatus.off();
    } else if (port == null || token == null) {
      // The no-op platforms (web, mobile) land here: nothing threw, but
      // there's no server either, so there is nothing to connect to.
      state = const McpServerStatus.off();
    } else {
      state = McpServerStatus.running(port: port, token: token);
    }
  }

  /// Whether a transition that was requested as [intent] may still write
  /// state. Two things say no: the provider was disposed while the socket
  /// work was in flight (a container torn down mid-test, the app closing —
  /// writing state after that throws), or a newer request has superseded
  /// it, in which case the newer one will publish the state that matches
  /// what the user last asked for.
  bool _mayPublish(int intent) => ref.mounted && intent == _intent;
}

final mcpViewModelProvider = NotifierProvider<McpViewModel, McpServerStatus>(
  McpViewModel.new,
);
