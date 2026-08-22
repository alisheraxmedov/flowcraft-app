import 'dart:io';

import 'package:flowcraft/services/export_file_sink.dart';
import 'package:flowcraft/services/importable_scene.dart';
import 'package:flowcraft/services/scene_import_exception.dart';

export 'package:flowcraft/services/scene_import_exception.dart';

/// Finds and reads scene files to import.
///
/// There is no native "Open…" dialog for the same reason there is no native
/// "Save as…" one: every file-picker package ships platform code, and this
/// app's zero-plugin dependency list is what keeps the macOS build out of
/// the CocoaPods dance (see CLAUDE.md). The substitute is to list the folder
/// exports already land in — `~/Documents/FlowCraft` — which is where a
/// user's own `.flowcraft.json` files actually are, plus a path field for
/// the file that came from somewhere else.
class SceneImportSource {
  SceneImportSource._();

  /// Most files a listing will return.
  ///
  /// A cap rather than a scroll-forever list: the folder is shared with PNG
  /// exports and whatever else the user has dropped there, and building
  /// thousands of rows to find one file helps nobody.
  static const int maxEntries = 200;

  /// Where [list] looks by default — the export folder.
  static String defaultDirectoryPath() => ExportFileSink.defaultDirectoryPath();

  /// Every `.json` file in [directoryPath], newest first.
  ///
  /// An absent folder is an empty list, not an error: it simply means
  /// nothing has been exported yet, and the dialog says so better than an
  /// exception would.
  static Future<List<ImportableScene>> list({String? directoryPath}) async {
    final directory = Directory(directoryPath ?? defaultDirectoryPath());
    if (!await directory.exists()) return const <ImportableScene>[];

    final found = <ImportableScene>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      // `.flowcraft.json` files end in `.json` too, so one test covers both
      // what this app writes and a plain scene payload from elsewhere.
      if (!name.toLowerCase().endsWith('.json')) continue;
      final stat = await entity.stat();
      found.add(
        ImportableScene(
          path: entity.path,
          name: name,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    found.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return found.length <= maxEntries ? found : found.sublist(0, maxEntries);
  }

  /// Reads [path] as UTF-8. Throws [FileSystemException] with the real
  /// reason — the dialog shows it rather than saying "import failed" — or
  /// [SceneImportTooLargeException] for a file over [maxSceneImportBytes].
  ///
  /// The size is checked with a `stat` *before* anything is read: the
  /// refusal must cost nothing, or a typed path to a multi-gigabyte file
  /// would have already frozen the window by the time it was refused.
  static Future<String> read(String path) async {
    final file = File(expandHome(path));
    final size = (await file.stat()).size;
    if (size > maxSceneImportBytes) {
      throw SceneImportTooLargeException(sizeBytes: size);
    }
    return file.readAsString();
  }

  /// Turns a leading `~` into the user's home directory.
  ///
  /// Typed paths come from humans, and a human writing a path by hand
  /// writes `~/Documents/…`. Leaving that unexpanded produces a
  /// "no such file" for a path that plainly exists.
  ///
  /// Only the bare `~` and `~/…` (`~\…` on Windows) forms are expanded.
  /// `~bob/…` names *another* user's home, which this deliberately does not
  /// resolve — substituting our own home for the `~` alone turned it into
  /// `/Users/alicebob/…`, a path that exists for nobody.
  static String expandHome(String path) {
    if (path != '~' &&
        !path.startsWith('~/') &&
        !(Platform.isWindows && path.startsWith(r'~\'))) {
      return path;
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return path;
    return '$home${path.substring(1)}';
  }
}
