/// The app's version, as the release build was told it at compile time.
///
/// CI passes `--dart-define=FLOWCRAFT_VERSION=<pubspec version>` to every
/// `flutter build`, so a tagged build reports the `pubspec.yaml` version
/// without a plugin (`package_info_plus` would be the usual route, and
/// this app ships zero plugins on purpose — see CLAUDE.md). A local
/// `flutter run` has no define and reports `dev`, which is the honest
/// answer for an unreleased build.
///
/// Surfaced in the MCP `initialize` handshake, on `GET /health`, and in the
/// `flowcraft_status` tool text, so a bug report filed from any of them
/// names the build it came from.
const String appVersion = String.fromEnvironment(
  'FLOWCRAFT_VERSION',
  defaultValue: 'dev',
);
