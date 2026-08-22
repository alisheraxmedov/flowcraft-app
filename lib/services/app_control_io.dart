import 'dart:io';

import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'app_control_exception.dart';
import 'flowcraft_control_server.dart';

export 'app_control_exception.dart';

/// Starts the MCP control server on desktop platforms only. Mobile targets
/// compile `dart:io` fine but have no legitimate local AI-CLI client to
/// talk to it, so [start] is a no-op there.
class AppControlServer {
  /// [port] is threaded all the way down rather than defaulting here, so
  /// there is exactly one place that decides it ([mcpServerPortProvider])
  /// and tests can ask for port 0 — `flutter test` runs files in parallel,
  /// and a fixed port would have them fighting over one socket.
  AppControlServer({required SketchController controller, required int port})
    : _server = _isDesktop
          ? FlowcraftControlServer(controller: controller, port: port)
          : null;

  static bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  final FlowcraftControlServer? _server;

  /// Connection details the UI shows so a user can point an AI CLI at the
  /// running app. All null until [start] has bound a port — and on the
  /// platforms where this class is a no-op, null forever.
  int? get boundPort => _server?.boundPort;
  String? get token => _server?.boundPort == null ? null : _server?.token;

  /// Throws [AppControlStartException] when the socket can't be bound —
  /// overwhelmingly "something else already holds the port" — or when the
  /// auth token can't be read or written. Translated here rather than left
  /// as raw `dart:io` exceptions so the view model can surface a reason
  /// without importing `dart:io`, and so the MCP card shows one short
  /// sentence rather than a `toString()` full of errno and absolute paths.
  Future<void> start() async {
    final server = _server;
    if (server == null) return;
    try {
      await server.start();
    } on SocketException catch (e) {
      // `osError.message` is the actionable half ("Address already in
      // use"); the rest of a SocketException's `toString()` is errno and
      // address noise that means nothing to a user.
      final detail = e.osError?.message ?? e.message;
      throw AppControlStartException(
        'Port ${server.port} is unavailable: $detail',
      );
    } on FileSystemException catch (e) {
      // The token lives in `~/.flowcraft`; a read-only or missing home is
      // the realistic way to land here.
      final detail = e.osError?.message ?? e.message;
      throw AppControlStartException(
        'Could not create the auth token in ${server.configDir.path}: '
        '$detail',
      );
    }
  }

  Future<void> stop() => _server?.stop() ?? Future<void>.value();
}
