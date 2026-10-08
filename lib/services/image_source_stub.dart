import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/image_source_core.dart';

/// Web fallback for [ImageSource]: there is no file system to read a `path`
/// from, so only `dataUrl` (and already-resolved `data`) entries work.
class ImageSource {
  ImageSource._();

  static Future<List<dynamic>> resolve(List<dynamic> raw) => resolveImages(
    raw,
    readPath: (_) async => throw DiagramSpecException(
      'Image "path" is not available on the web build; send a "dataUrl".',
    ),
  );
}
