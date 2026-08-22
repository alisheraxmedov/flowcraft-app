import 'package:flowcraft/flowcraft.dart';

export 'app_control_exception.dart';

/// Web fallback for [AppControlServer] — the MCP control server needs
/// `dart:io.HttpServer`, which doesn't exist on web. Selected in place of
/// `app_control_io.dart` by the `dart.library.io` conditional import in
/// `app_control.dart` whenever compiling for a target without `dart:io`.
class AppControlServer {
  AppControlServer({required SketchController controller, required int port});

  /// Always null here: with no server there is no port and no token, so
  /// the MCP card simply has no connection details to show.
  int? get boundPort => null;
  String? get token => null;

  Future<void> start() async {}
  Future<void> stop() async {}
}
