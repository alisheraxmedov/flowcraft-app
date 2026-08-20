import 'dart:io';

/// Constants shared with the FlowCraft app's local control server.
///
/// Deliberately duplicated rather than imported from a shared package: the
/// MCP bridge and the FlowCraft desktop app are two independent processes
/// on purpose (`dart_mcp` only supports stdio, so this server must be a
/// separate process spawned by the AI CLI, not the app itself).
class FlowcraftConfig {
  FlowcraftConfig._();

  static const int controlPort = 5199;

  static Uri controlUri(String path) =>
      Uri.parse('http://127.0.0.1:$controlPort$path');

  static Directory get configDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return Directory('$home${Platform.pathSeparator}.flowcraft');
  }

  static File get tokenFile => File(
        '${configDir.path}${Platform.pathSeparator}control.token',
      );

  /// Reads the shared control-server auth token, or `null` if the
  /// FlowCraft app has never started its control server on this machine.
  static String? readToken() {
    final file = tokenFile;
    if (!file.existsSync()) return null;
    final token = file.readAsStringSync().trim();
    return token.isEmpty ? null : token;
  }
}
