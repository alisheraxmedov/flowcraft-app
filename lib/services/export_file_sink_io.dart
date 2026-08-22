import 'dart:io';

/// Writes exported artefacts into `~/Documents/FlowCraft` and hands them to
/// the OS file manager.
///
/// There is deliberately no native "Save as…" dialog: every Flutter package
/// that offers one ships platform code, and this app keeps a zero-plugin
/// dependency list (see CLAUDE.md — plugins re-arm the macOS CocoaPods
/// build dance). A fixed, discoverable folder plus a "Reveal" affordance
/// buys most of the dialog's value without that cost.
class ExportFileSink {
  ExportFileSink._();

  static const String _folderName = 'FlowCraft';

  /// Absolute path of the export folder for the current user. Not
  /// guaranteed to exist yet — [write] creates it on demand.
  static String defaultDirectoryPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final sep = Platform.pathSeparator;
    return '$home${sep}Documents$sep$_folderName';
  }

  /// Writes [bytes] as [fileName] and returns the absolute path written.
  ///
  /// [directoryPath] overrides the destination folder; tests pass a temp
  /// directory through it so they never touch the real `$HOME`. Throws
  /// [FileSystemException] on permission/disk failures — callers surface
  /// the message rather than swallowing it.
  static Future<String> write({
    required String fileName,
    required List<int> bytes,
    String? directoryPath,
  }) async {
    final directory = Directory(directoryPath ?? defaultDirectoryPath());
    await directory.create(recursive: true);
    final file =
        File('${directory.path}${Platform.pathSeparator}$fileName');
    // `flush: true` so the path we hand the user in the "Saved to …"
    // snackbar is readable by the file manager the moment they click
    // Reveal, not once the OS gets around to flushing its page cache.
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Opens the platform file manager with [path] selected. Returns whether
  /// that succeeded — a failed reveal is a cosmetic problem, so it is
  /// reported through the return value instead of thrown into the UI.
  static Future<bool> reveal(String path) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', ['-R', path]);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        // `explorer` exits with a non-zero code even when it succeeds, so
        // its status says nothing — reaching this line without throwing is
        // the only success signal available.
        await Process.run('explorer', ['/select,$path']);
        return true;
      }
      if (Platform.isLinux) {
        // No portable "select this file" verb on Linux; opening the parent
        // folder is the closest equivalent every desktop environment has.
        final result =
            await Process.run('xdg-open', [File(path).parent.path]);
        return result.exitCode == 0;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
