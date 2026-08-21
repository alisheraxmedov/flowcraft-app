import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/services/app_control.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// Whether the MCP control server is running (`true` = enabled). Owns the
/// [AppControlServer] instance for the lifetime of the app: starts it on
/// first read, stops it on dispose, and starts/stops it again on [toggle].
class McpViewModel extends Notifier<bool> {
  late final AppControlServer _server;

  /// Resolves once the *initial* startup attempt triggered from [build] has
  /// finished — either it started successfully, or it failed and that
  /// failure was already logged via [debugPrint]. Callers (e.g. the splash
  /// screen) can `await` this for a genuine readiness signal instead of
  /// guessing with a fixed delay.
  late final Future<void> ready;

  @override
  bool build() {
    // `read`, not `watch` — this only needs the controller instance once,
    // not a rebuild every time the canvas changes.
    final controller = ref.read(sketchControllerProvider);
    _server = AppControlServer(controller: controller);
    ready = _server.start().catchError((Object e) {
      debugPrint('FlowCraft control server failed to start: $e');
    });
    ref.onDispose(() => _server.stop());
    return true;
  }

  void toggle() {
    final enabling = !state;
    state = enabling;
    final future = enabling ? _server.start() : _server.stop();
    future.catchError((Object e) {
      debugPrint(
        'FlowCraft control server ${enabling ? 'start' : 'stop'} failed: $e',
      );
    });
  }
}

final mcpViewModelProvider = NotifierProvider<McpViewModel, bool>(
  McpViewModel.new,
);
