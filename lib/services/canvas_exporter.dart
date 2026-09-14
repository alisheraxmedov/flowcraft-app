import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/rendering/sketch_painter.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/export_file_sink.dart';

/// Never reaches a pixel: [SketchPainter] only draws selection chrome for
/// ids present in `selectedIds`, and every export passes an empty set.
const Color _unusedSelectionColor = Color(0x00000000);

/// Renders the sketch scene to a PNG and puts export artefacts on disk.
///
/// Exports cover the *whole* scene rather than the visible viewport — the
/// user's current pan/zoom is a navigation state, not a framing decision,
/// and cropping to it silently loses work that sits off-screen.
class CanvasExporter {
  CanvasExporter._();

  /// Largest side an exported image may have, in pixels. Comfortably inside
  /// the 8192px max texture size that GPU backends of this era guarantee.
  static const double maxImageDimension = 8192;

  /// Rasterises [elements] to PNG bytes.
  ///
  /// The image spans the union of every element's bounds inflated by
  /// [padding] (canvas units), scaled by [pixelRatio]. [background] is
  /// painted opaque underneath so the result matches what the canvas shows
  /// rather than arriving with a transparent void behind hachure fills.
  ///
  /// An empty [elements] list yields a blank `padding × 2` square instead of
  /// throwing, so a caller that skipped the emptiness check still gets a
  /// valid image back.
  static Future<Uint8List> renderPng(
    List<SketchElement> elements, {
    required Color background,
    double pixelRatio = 2.0,
    double padding = 32,
  }) async {
    assert(pixelRatio > 0, 'pixelRatio must be positive');
    assert(padding >= 0, 'padding must not be negative');

    final content = contentBounds(elements).inflate(padding);
    // Clamp before rasterising: a wide scene at the default 2x ratio can
    // ask for an image past Skia's max texture size, and `toImage` answers
    // an oversized request by allocating w × h × 4 bytes and taking the app
    // down with it. Scaling down beats crashing on a legitimate export.
    final effectiveRatio = math.min(
      pixelRatio,
      maxImageDimension / math.max(content.width, content.height),
    );
    final widthPx = math.max(1, (content.width * effectiveRatio).round());
    final heightPx = math.max(1, (content.height * effectiveRatio).round());
    final imageRect = Rect.fromLTWH(
      0,
      0,
      widthPx.toDouble(),
      heightPx.toDouble(),
    );

    // Maps canvas-space onto image-space: the padded content's top-left
    // lands on pixel (0, 0) and one canvas unit becomes `pixelRatio`
    // pixels. `maxZoom` is widened because `FlowViewport` clamps zoom to
    // 4x by default — a legitimate constraint for interactive panning, but
    // not for a 6x poster-resolution export.
    final viewport = FlowViewport(
      offset: content.topLeft * -effectiveRatio,
      zoom: effectiveRatio,
      minZoom: math.min(0.1, effectiveRatio),
      maxZoom: math.max(4.0, effectiveRatio),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, imageRect);
    canvas.drawRect(
      imageRect,
      Paint()..color = background.withValues(alpha: 1.0),
    );

    // A throwaway cache: the export paints once, and the cache owns native
    // `TextPainter`s that must be released rather than left to the GC.
    final cache = SketchRenderCache();
    try {
      SketchPainter(
        elements: elements,
        // Empty selection + null edit target so selection handles and
        // half-finished inline text never leak into an exported file.
        selectedIds: const <String>{},
        viewport: viewport,
        paintGen: 0,
        cache: cache,
        selectionColor: _unusedSelectionColor,
        editingElementId: null,
        canvasSize: imageRect.size,
      ).paint(canvas, imageRect.size);
    } finally {
      cache.dispose();
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(widthPx, heightPx);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('The canvas could not be encoded as PNG.');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Axis-aligned union of every element's bounds, or [Rect.zero] when
  /// there is nothing to measure. Non-finite bounds are skipped so one
  /// degenerate element can't poison the whole frame.
  static Rect contentBounds(List<SketchElement> elements) {
    Rect? union;
    for (final element in elements) {
      final bounds = element.bounds;
      if (!bounds.isFinite) continue;
      union = union == null ? bounds : union.expandToInclude(bounds);
    }
    return union ?? Rect.zero;
  }

  /// Writes [bytes] as [fileName] into the user's `Documents/FlowCraft`
  /// folder (created on demand) and returns the absolute path.
  static Future<String> writeExport({
    required String fileName,
    required List<int> bytes,
    String? directoryPath,
  }) {
    return ExportFileSink.write(
      fileName: fileName,
      bytes: bytes,
      directoryPath: directoryPath,
    );
  }

  /// Selects [path] in the platform file manager. Returns `false` instead
  /// of throwing when the platform has no file manager to talk to.
  static Future<bool> revealInFileManager(String path) =>
      ExportFileSink.reveal(path);

  /// Builds a filesystem-safe name like `my-diagram-20260822-143501.png`.
  /// Timestamped because there is no save dialog to warn about overwriting
  /// a previous export; two exports inside the same second are told apart
  /// by [ExportFileSink.write], which suffixes `-2`, `-3`, … rather than
  /// overwrite.
  static String timestampedFileName(
    String baseName,
    String extension, {
    DateTime? now,
  }) {
    final stamp = _stamp(now ?? DateTime.now());
    final safe = sanitizeBaseName(baseName);
    return '$safe-$stamp.$extension';
  }

  /// Strips path separators and characters Windows rejects in filenames,
  /// collapsing whatever is left into a lowercase slug.
  static String sanitizeBaseName(String baseName) {
    final slug = baseName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return 'flowcraft';
    return slug.length <= 48 ? slug : slug.substring(0, 48);
  }

  static String _stamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '-${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
