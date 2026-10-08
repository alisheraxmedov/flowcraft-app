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

/// Longest side, and most pixels, an image may declare. `maxImageBytes` caps
/// only the *compressed* size; a few-KB PNG can declare 60000x60000 and
/// decode to gigabytes (CWE-409), so the declared size is checked first.
const int maxImageSide = 8192;
const int maxImagePixels = 32 * 1000 * 1000;

/// The pixel size [bytes] declares, read from the header by the engine
/// without decoding any pixels. Throws [DiagramSpecException] when [bytes]
/// is not a recognised image or declares more than [maxImageSide] /
/// [maxImagePixels] — call this before any `instantiateImageCodec`.
Future<({int width, int height})> checkedImageSize(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    bytes,
  );
  try {
    final ui.ImageDescriptor d;
    try {
      d = await ui.ImageDescriptor.encoded(buffer);
    } catch (_) {
      throw DiagramSpecException('The image data could not be decoded.');
    }
    final (w, h) = (d.width, d.height);
    d.dispose();
    if (w > maxImageSide || h > maxImageSide || w * h > maxImagePixels) {
      throw DiagramSpecException(
        'Image is ${w}x$h px; the limit is $maxImageSide px per side and '
        '${maxImagePixels ~/ 1000000} megapixels.',
      );
    }
    return (width: w, height: h);
  } finally {
    buffer.dispose();
  }
}

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
    // Always validated, even when the caller gave a size: the declared
    // pixels, not the stated ones, are what a decode would allocate.
    if (map['data'] is String) await _fillNaturalSize(map);
    out.add(map);
  }
  return out;
}

/// Validates [map]'s image and sets its missing `width`/`height` from the
/// declared pixels. Bad base64 is left for the parser to reject with its
/// own message.
Future<void> _fillNaturalSize(Map<String, dynamic> map) async {
  final Uint8List bytes;
  try {
    bytes = base64Decode(map['data'] as String);
  } on FormatException {
    return;
  }
  final size = await checkedImageSize(bytes);
  final w = size.width.toDouble(), h = size.height.toDouble();
  final gw = map['width'], gh = map['height'];
  if (gw is num && gw > 0 && gh == null) {
    map['height'] = gw * h / w;
  } else if (gh is num && gh > 0 && gw == null) {
    map['width'] = gh * w / h;
  } else if (gw == null && gh == null) {
    map['width'] = w;
    map['height'] = h;
  }
}
