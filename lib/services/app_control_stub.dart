import 'package:flowcraft/flowcraft.dart';

/// Web fallback for [AppControlServer] — the MCP control server needs
/// `dart:io.HttpServer`, which doesn't exist on web. Selected in place of
/// `app_control_io.dart` by the `dart.library.io` conditional import in
/// `app_control.dart` whenever compiling for a target without `dart:io`.
class AppControlServer {
  AppControlServer({required SketchController controller});

  Future<void> start() async {}
  Future<void> stop() async {}
}
