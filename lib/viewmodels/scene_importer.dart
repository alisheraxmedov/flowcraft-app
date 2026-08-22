import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show immutable;

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
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
      // Through `pasteFromJson`, not `addAll`: it mints fresh ids, and a
      // file exported from *this* board carries the ids already on it —
      // two elements sharing an id would hand selection, hit-testing and
      // MCP addressing a single handle for both.
      SceneImportMode.add => controller.pasteFromJson(
        json,
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
