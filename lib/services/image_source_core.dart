import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/diagram_spec.dart';

/// File extensions an image `path` may have, and the mime type each means.
const Map<String, String> imageExtensionMimes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

/// Reads the file at an image `path` entry; supplied by the io/stub split.
typedef ImagePathReader =
    Future<(String mimeType, Uint8List bytes)> Function(String path);

final RegExp _dataUrl = RegExp(
  r'^data:([A-Za-z0-9.+/-]+);base64,(.*)$',
  dotAll: true,
);

/// Shared body of `ImageSource.resolve`: turns each `type:'image'` entry
/// that names a `path` or `dataUrl` into `{mimeType, data}` (base64), and
/// fills a missing `width`/`height` from the image's natural size (one given
/// keeps the aspect ratio). Other entries pass through untouched; checking
/// that the result is a legal image is `parseDiagramElements`'s job.
Future<List<dynamic>> resolveImages(
  List<dynamic> raw, {
  required ImagePathReader readPath,
}) async {
  final out = <dynamic>[];
  for (final entry in raw) {
    if (entry is! Map || entry['type'] != 'image') {
      out.add(entry);
      continue;
    }
    final map = Map<String, dynamic>.from(entry);
    final path = map.remove('path');
    final dataUrl = map.remove('dataUrl');
    if (path != null && dataUrl != null) {
      throw DiagramSpecException(
        'An image takes "path" or "dataUrl", not both.',
      );
    }
    if (path != null) {
      if (path is! String) {
        throw DiagramSpecException('"path" must be a string, got: $path');
      }
      final (mime, bytes) = await readPath(path);
      map['mimeType'] = mime;
      map['data'] = base64Encode(bytes);
    } else if (dataUrl != null) {
      if (dataUrl is! String) {
        throw DiagramSpecException('"dataUrl" must be a string.');
      }
      final m = _dataUrl.firstMatch(dataUrl);
      if (m == null) {
        throw DiagramSpecException(
          '"dataUrl" must look like data:image/png;base64,<data>.',
        );
      }
      if (!imageMimeTypes.contains(m[1])) {
        throw DiagramSpecException(
          'Unsupported image type "${m[1]}". Use one of '
          '${imageMimeTypes.join(', ')}.',
        );
      }
      final data = m[2]!;
      if (data.length > maxImageBytes * 4 ~/ 3 + 4) {
        throw DiagramSpecException(
          'Image is larger than the ${maxImageBytes ~/ (1024 * 1024)} MiB limit.',
        );
      }
      map['mimeType'] = m[1];
      map['data'] = data;
    }
    if ((map['width'] == null || map['height'] == null) &&
        map['data'] is String) {
      await _fillNaturalSize(map);
    }
    out.add(map);
  }
  return out;
}

/// Sets the missing `width`/`height` of [map] from its decoded pixels. Bad
/// base64 or an undecodable image is left for the parser to reject with its
/// own message.
Future<void> _fillNaturalSize(Map<String, dynamic> map) async {
  final Uint8List bytes;
  try {
    bytes = base64Decode(map['data'] as String);
  } on FormatException {
    return;
  }
  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
  } catch (_) {
    throw DiagramSpecException('The image data could not be decoded.');
  }
  try {
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble(), h = frame.image.height.toDouble();
    frame.image.dispose();
    final gw = map['width'], gh = map['height'];
    if (gw is num && gw > 0) {
      map['height'] = gw * h / w;
    } else if (gh is num && gh > 0) {
      map['width'] = gh * w / h;
    } else {
      map['width'] = w;
      map['height'] = h;
    }
  } finally {
    codec.dispose();
  }
}
