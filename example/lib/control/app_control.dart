/// Platform-agnostic entry point for the app's MCP control server.
///
/// `dart:io.HttpServer` doesn't exist on web, so `main.dart` must never
/// import `flowcraft_control_server.dart` (or `dart:io`) directly — that
/// would break `flutter build web`. This conditional export picks the real
/// implementation when `dart:io` is available and a no-op stub otherwise.
library;

export 'app_control_stub.dart' if (dart.library.io) 'app_control_io.dart';
