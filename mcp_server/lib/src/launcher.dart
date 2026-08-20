import 'dart:io';

import 'config.dart';

/// Best-effort discovery and launch of the FlowCraft desktop app binary.
///
/// There is no single guaranteed install path across machines, so this
/// checks, in order: the `FLOWCRAFT_APP_PATH` environment variable, then a
/// short list of well-known per-OS install locations produced by the
/// project's packaging (see `.github/workflows/build-desktop.yml`).
class FlowcraftLauncher {
  FlowcraftLauncher._();

  static String? resolveAppPath() {
    final override = Platform.environment['FLOWCRAFT_APP_PATH'];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    for (final candidate in _candidates()) {
      if (FileSystemEntity.typeSync(candidate) !=
          FileSystemEntityType.notFound) {
        return candidate;
      }
    }
    return null;
  }

  static List<String> _candidates() {
    if (Platform.isMacOS) {
      return const [
        '/Applications/FlowCraft.app',
        '/Applications/flowcraft_example.app',
      ];
    }
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final programFiles = Platform.environment['ProgramFiles'];
      return [
        if (localAppData != null)
          '$localAppData\\FlowCraft\\flowcraft_example.exe',
        if (programFiles != null)
          '$programFiles\\FlowCraft\\flowcraft_example.exe',
      ];
    }
    if (Platform.isLinux) {
      return const ['/usr/bin/flowcraft', '/usr/local/bin/flowcraft'];
    }
    return const [];
  }

  /// Launches the app (best-effort) and polls `/health` until it answers
  /// or [timeout] elapses. Returns `true` once the app is ready.
  static Future<bool> launchAndWait({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (await _healthOk()) return true;

    final path = resolveAppPath();
    if (path == null) return false;

    if (Platform.isMacOS && path.endsWith('.app')) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else {
      await Process.start(path, const [], mode: ProcessStartMode.detached);
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _healthOk()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  static Future<bool> _healthOk() async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(FlowcraftConfig.controlUri('/health'))
          .timeout(const Duration(seconds: 1));
      final response =
          await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
