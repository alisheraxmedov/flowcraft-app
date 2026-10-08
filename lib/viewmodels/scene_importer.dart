import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show immutable;

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/services/canvas_exporter.dart';
import 'package:flowcraft/services/diagram_layout.dart';
import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/text_import/dbml.dart';
import 'package:flowcraft/services/text_import/detect.dart';
import 'package:flowcraft/services/text_import/excalidraw.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// How an imported scene meets the one already on the canvas.
enum SceneImportMode {
  /// Adds the imported elements alongside what is there, selected.
  add,

  /// Swaps the canvas for the imported scene, undoably.
  replace,
}

/// What an import did, in enough detail to tell the user the truth.
@immutable
class SceneImportResult {
  const SceneImportResult.success({
    required this.imported,
    required this.dropped,
  }) : error = null;

  const SceneImportResult.failure(this.error) : imported = 0, dropped = 0;

  final int imported;

  /// Elements in the payload this build could not decode. Reported rather
  /// than swallowed: a partial import that looked like a clean one is how
  /// someone finds out weeks later that half a diagram never arrived.
  final int dropped;

  final String? error;

  bool get succeeded => error == null;
}

/// Puts a scene payload — from a file or from a paste box — on the canvas.
///
/// Separate from the dialogs that call it so both routes behave identically
/// and so the behaviour is testable without pumping a widget.
class SceneImporter {
  SceneImporter._();

  /// Imports [json] into [controller].
  ///
  /// Never throws: a scene file is user input, and every way it can be
  /// wrong (not JSON, not a scene, a schema from a newer build) is a
  /// sentence to show, not a crash. That is the opposite of the paste
  /// shortcut's contract — there the payload is whatever the clipboard
  /// held and silence is right; here the user explicitly asked for *this*
  /// file and deserves to know why it didn't work.
  static SceneImportResult import(
    SketchController controller,
    String json, {
    required SceneImportMode mode,
  }) {
    final SketchSceneLoad load;
    try {
      load = SketchSerializer.loadJson(json);
    } catch (error) {
      return SceneImportResult.failure(_describe(error));
    }
    if (load.elements.isEmpty) {
      return SceneImportResult.failure(
        load.errors.isEmpty
            ? 'That file holds no elements.'
            : 'None of the ${load.droppedCount} elements in that file could '
                  'be read by this version of FlowCraft.',
      );
    }

    final imported = switch (mode) {
      // Through `pasteElements`, not `addAll`: it mints fresh ids, and a
      // file exported from *this* board carries the ids already on it —
      // two elements sharing an id would hand selection, hit-testing and
      // MCP addressing a single handle for both. The already-decoded list
      // goes in, not [json]: the payload was parsed once above, and a
      // multi-megabyte file must not be parsed twice on the UI isolate.
      SceneImportMode.add => controller.pasteElements(
        load.elements,
        offset: Offset.zero,
      ),
      // `replaceAll`, not `loadScene`: this is an edit of the open project,
      // so it belongs in undo history. `loadScene` would discard it, and a
      // replace that can't be undone is a trap.
      SceneImportMode.replace => _replace(controller, load),
    };

    return SceneImportResult.success(
      imported: imported,
      dropped: load.droppedCount,
    );
  }

  /// [import] for pasted text of any supported format: FlowCraft JSON keeps
  /// its existing path; Mermaid / DBML are laid out by `buildDiagram`;
  /// Excalidraw elements are placed as drawn. Like [import] it never throws,
  /// and a syntax error comes back with its `line N:` prefix.
  ///
  /// [SceneImportMode.add] parks the result right of existing content (the
  /// same spot `flowcraft_diagram` uses); replace swaps the canvas. Either
  /// way the camera frames it and the elements animate in.
  static SceneImportResult importText(
    SketchController controller,
    String text, {
    required SceneImportMode mode,
  }) {
    final format = detectTextFormat(text);
    // Unknown text takes the JSON path too, so a mangled payload keeps the
    // familiar "not valid JSON" answer instead of a new one.
    if (format == TextFormat.json || format == TextFormat.unknown) {
      return import(controller, text, mode: mode);
    }
    final replace = mode == SceneImportMode.replace;
    final existing = controller.elements;
    final origin = replace || existing.isEmpty
        ? Offset.zero
        : CanvasExporter.contentBounds(existing).topRight.translate(96, 0);

    List<SketchElement> elements;
    var dropped = 0;
    try {
      switch (format) {
        case TextFormat.mermaid || TextFormat.dbml:
          final v = format == TextFormat.mermaid
              ? parseMermaid(text)
              : parseDbml(text);
          elements = buildDiagram(
            nodes: v['nodes'] as List,
            edges: v['edges'] as List,
            direction: v['direction'] as String? ?? 'TB',
            frames: v['frames'] as List? ?? const [],
            origin: origin,
          ).elements;
        case TextFormat.excalidraw:
          final parsed = parseExcalidraw(text);
          dropped = parsed.dropped;
          final bounds = parsed.elements.isEmpty
              ? Rect.zero
              : CanvasExporter.contentBounds(parsed.elements);
          // Not `pasteElements`: it re-mints ids, which would orphan the
          // arrow bindings the parser just wired up.
          elements = [
            for (final e in parsed.elements)
              e.translate(origin - bounds.topLeft),
          ];
        default:
          return import(controller, text, mode: mode);
      }
    } on DiagramSpecException catch (e) {
      return SceneImportResult.failure(e.message);
    } catch (_) {
      return const SceneImportResult.failure('That text could not be read.');
    }
    if (elements.isEmpty) {
      return const SceneImportResult.failure('That text holds no elements.');
    }

    if (replace) {
      controller.replaceAll(elements);
    } else {
      controller.addAll(elements);
    }
    final ids = [for (final e in elements) e.id];
    controller
      ..selectMany(ids)
      ..requestFrame(CanvasExporter.contentBounds(elements))
      ..requestReveal(ids);
    return SceneImportResult.success(
      imported: elements.length,
      dropped: dropped,
    );
  }

  static int _replace(SketchController controller, SketchSceneLoad load) {
    controller.replaceAll(load.elements);
    return load.elements.length;
  }

  /// Turns a parse failure into something a person can act on.
  ///
  /// Deliberately not `'$error'`: the failures here are a `FormatException`
  /// from `jsonDecode` and a `TypeError` from casting a payload that isn't
  /// shaped like a scene, and neither reads as anything but a crash report.
  static String _describe(Object error) {
    if (error is FormatException) return 'That file is not valid JSON.';
    // The schema-version guard names both versions in its own message,
    // which is exactly what the user needs to hear.
    if (error is StateError) return error.message;
    return 'That file is not a FlowCraft scene.';
  }
}
