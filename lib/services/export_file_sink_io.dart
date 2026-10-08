import 'dart:io';
import 'dart:math' as math;

import 'package:flowcraft/services/export_path_exception.dart';
import 'package:flowcraft/services/project_repository_io.dart';
import 'package:flowcraft/services/scene_import_source.dart';

export 'package:flowcraft/services/export_path_exception.dart';

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
    final home =
        Platform.environment['HOME'] ??
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
  ///
  /// Never overwrites: a name already taken gets `-2`, `-3`, … before its
  /// extension. The timestamp in an export name has one-second resolution,
  /// so a double-click on the menu item produced two exports with one
  /// name, and the second silently replaced the first.
  static Future<String> write({
    required String fileName,
    required List<int> bytes,
    String? directoryPath,
  }) async {
    final directory = Directory(directoryPath ?? defaultDirectoryPath());
    await directory.create(recursive: true);
    final file = await _unclaimed(directory, fileName);
    // `flush: true` so the path we hand the user in the "Saved to …"
    // snackbar is readable by the file manager the moment they click
    // Reveal, not once the OS gets around to flushing its page cache.
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Writes [bytes] to the caller-chosen [path] — the policy gate for
  /// anything an MCP client can name. Returns the absolute path written, or
  /// throws [ExportPathException] naming the rule that refused it.
  ///
  /// Rules, in order: `~` expands; the path must be absolute and free of
  /// `..`; its parent must already exist as a directory (nothing is created
  /// recursively); the target must not be a symlink or a directory; the
  /// resolved parent must not sit inside [protectedDirectoryPath] (default
  /// `~/.flowcraft`, which holds the projects *and* the control-server
  /// token, so an overwrite there would cost work or hijack auth); an
  /// existing file needs [overwrite]. The write is temp + rename beside the
  /// target so a crash never leaves a half-written file.
  ///
  /// The extension is the caller's check (it knows the format).
  /// ponytail: exists-check to rename is not atomic, so a file created in
  /// that window is replaced even with overwrite false; use a hard-link
  /// rename if exports ever run against untrusted concurrent writers.
  static Future<String> writeTo(
    String path,
    List<int> bytes, {
    required bool overwrite,
    String? protectedDirectoryPath,
  }) async {
    final target = SceneImportSource.expandHome(path);
    if (!File(target).isAbsolute) {
      throw const ExportPathException(
        'path must be absolute (or start with ~/)',
      );
    }
    final sep = Platform.pathSeparator;
    if (target.split(RegExp(r'[\\/]')).contains('..')) {
      throw const ExportPathException("path must not contain '..' segments");
    }
    final file = File(target);
    final parent = file.parent;
    if (await FileSystemEntity.type(parent.path) !=
        FileSystemEntityType.directory) {
      throw ExportPathException(
        'parent directory does not exist (or is not a directory): '
        '${parent.path}',
      );
    }
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const ExportPathException('refusing to write through a symlink');
    }
    if (type == FileSystemEntityType.directory) {
      throw const ExportPathException('path is a directory, not a file');
    }

    final protectedRoot = Directory(
      protectedDirectoryPath ??
          Directory(ProjectRepository.defaultDirectoryPath()).parent.path,
    );
    final resolvedParent = await parent.resolveSymbolicLinks();
    final resolvedProtected = await protectedRoot.exists()
        ? await protectedRoot.resolveSymbolicLinks()
        : protectedRoot.path;
    // macOS and Windows volumes are case-insensitive by default.
    String fold(String s) => Platform.isLinux ? s : s.toLowerCase();
    final p = fold(resolvedParent);
    final r = fold(resolvedProtected);
    if (p == r || p.startsWith(r.endsWith(sep) ? r : '$r$sep')) {
      throw const ExportPathException(
        'refusing to write inside the FlowCraft data directory (~/.flowcraft)',
      );
    }

    if (type != FileSystemEntityType.notFound && !overwrite) {
      throw const ExportPathException(
        'file already exists; set overwrite: true to replace it',
      );
    }

    final temp = File(
      '$target.${pid}_${math.Random.secure().nextInt(1 << 32)}.tmp',
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    return target;
  }

  /// [fileName] inside [directory], or the first `-N` variant of it that
  /// does not exist yet. The suffix goes before the *first* dot so a
  /// compound extension (`.flowcraft.json`) stays intact.
  static Future<File> _unclaimed(Directory directory, String fileName) async {
    final sep = Platform.pathSeparator;
    final dot = fileName.indexOf('.');
    final stem = dot < 0 ? fileName : fileName.substring(0, dot);
    final extension = dot < 0 ? '' : fileName.substring(dot);
    var candidate = File('${directory.path}$sep$fileName');
    for (var n = 2; await candidate.exists(); n++) {
      candidate = File('${directory.path}$sep$stem-$n$extension');
    }
    return candidate;
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
        final result = await Process.run('xdg-open', [File(path).parent.path]);
        return result.exitCode == 0;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
