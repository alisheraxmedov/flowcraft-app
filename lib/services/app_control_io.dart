import 'dart:io';

import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'flowcraft_control_server.dart';

/// Starts the MCP control server on desktop platforms only. Mobile targets
/// compile `dart:io` fine but have no legitimate local AI-CLI client to
/// talk to it, so [start] is a no-op there.
class AppControlServer {
  AppControlServer({required SketchController controller})
      : _server = _isDesktop
            ? FlowcraftControlServer(controller: controller)
            : null;

  static bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  final FlowcraftControlServer? _server;

  Future<void> start() => _server?.start() ?? Future<void>.value();
  Future<void> stop() => _server?.stop() ?? Future<void>.value();
}
