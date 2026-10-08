import 'dart:io';
import 'dart:typed_data';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/image_source_core.dart';
import 'package:flowcraft/services/scene_import_source.dart';

/// Resolves the `path` / `dataUrl` forms of a draw payload's images to bytes
/// before the (synchronous) diagram parser sees them.
///
/// A path comes from a model, so it is treated as hostile: absolute (or `~`)
/// only, a known image extension, a plain file (not a directory, not a
/// symlink that could point anywhere), and its size is `stat`ed *before* a
/// single byte is read.
class ImageSource {
  ImageSource._();

  static Future<List<dynamic>> resolve(List<dynamic> raw) =>
      resolveImages(raw, readPath: _read);

  static Future<(String, Uint8List)> _read(String rawPath) async {
    final path = SceneImportSource.expandHome(rawPath);
    final file = File(path);
    if (!file.isAbsolute) {
      throw DiagramSpecException(
        'Image path "$rawPath" must be absolute (or start with ~/).',
      );
    }
    final dot = path.lastIndexOf('.');
    final mime = dot < 0
        ? null
        : imageExtensionMimes[path.substring(dot + 1).toLowerCase()];
    if (mime == null) {
      throw DiagramSpecException(
        'Image path "$rawPath" must end in '
        '${imageExtensionMimes.keys.join(', ')}.',
      );
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw DiagramSpecException('Image file "$rawPath" does not exist.');
    }
    if (type != FileSystemEntityType.file) {
      throw DiagramSpecException(
        'Image path "$rawPath" is not a regular file (directories and '
        'symlinks are refused).',
      );
    }
    final size = (await file.stat()).size;
    if (size > maxImageBytes) {
      throw DiagramSpecException(
        'Image "$rawPath" is $size bytes; the limit is $maxImageBytes '
        '(${maxImageBytes ~/ (1024 * 1024)} MiB).',
      );
    }
    final bytes = await file.readAsBytes();
    // The file may have grown between stat and read.
    if (bytes.length > maxImageBytes) {
      throw DiagramSpecException('Image "$rawPath" grew past the size limit.');
    }
    return (mime, bytes);
  }
}
