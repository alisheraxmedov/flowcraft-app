import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';

/// Copy / cut / paste between the canvas and the *system* clipboard.
///
/// The system clipboard rather than a private in-app buffer, and the
/// `SketchSerializer` scene format rather than a bespoke one, so a selection
/// copied in one FlowCraft window pastes into another — and into a saved
/// `.flowcraft.json` — with no second format to keep in step.
class CanvasClipboard {
  CanvasClipboard._();

  /// Puts the selection on the clipboard. No-op when nothing is selected.
  static Future<void> copy(
    SketchController controller,
    ScaffoldMessengerState messenger,
  ) async {
    final json = controller.copySelectionToJson();
    if (json == null) return;
    await _write(json, messenger);
  }

  /// Copy, then remove — and only remove if the copy actually landed, or a
  /// failed clipboard write would turn Cut into Delete.
  static Future<void> cut(
    SketchController controller,
    ScaffoldMessengerState messenger,
  ) async {
    final json = controller.copySelectionToJson();
    if (json == null) return;
    if (await _write(json, messenger)) controller.removeSelected();
  }

  /// Adds whatever the clipboard holds, if it turns out to be a scene.
  ///
  /// [SketchController.pasteFromJson] already answers arbitrary text with
  /// `0` instead of throwing, so there is deliberately no `try` around it
  /// here: one there would also swallow real bugs in the paste path and
  /// leave them looking like an unlucky clipboard.
  static Future<void> paste(
    SketchController controller,
    ScaffoldMessengerState messenger,
  ) async {
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (error) {
      ExportFeedback.showError(
        messenger,
        'Could not read the clipboard: $error',
      );
      return;
    }
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    controller.pasteFromJson(text);
  }

  /// Writes [json] and reports a platform-channel refusal rather than
  /// claiming a copy that never happened.
  static Future<bool> _write(
    String json,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: json));
      return true;
    } catch (error) {
      ExportFeedback.showError(messenger, 'Could not copy: $error');
      return false;
    }
  }
}
