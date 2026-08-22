/// Why the MCP control server refused to start, phrased for a human.
///
/// Deliberately platform-neutral: the `dart:io` implementation translates
/// its [SocketException]s into this, so the view model — and the widgets
/// reading it — never import `dart:io`. That's what keeps the web target
/// compiling, and it keeps socket-level trivia out of the UI layer.
///
/// Re-exported by both `app_control_io.dart` and `app_control_stub.dart`
/// so it resolves through `app_control.dart`'s conditional export either
/// way.
class AppControlStartException implements Exception {
  const AppControlStartException(this.reason);

  /// A single short sentence, safe to render straight into the UI.
  final String reason;

  @override
  String toString() => reason;
}
