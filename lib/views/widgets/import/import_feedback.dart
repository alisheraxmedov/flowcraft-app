import 'package:flutter/material.dart';

import 'package:flowcraft/viewmodels/scene_importer.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';

/// Says what an import actually did.
///
/// Its whole reason to exist is the dropped-element case. `SketchSerializer`
/// skips elements it can't decode so one bad shape doesn't cost the user the
/// other forty — but an import that quietly arrives short is how someone
/// discovers, weeks later, that half a diagram never made it. The count is
/// therefore part of the success message, not an error hidden elsewhere.
class ImportFeedback {
  ImportFeedback._();

  static void report(
    ScaffoldMessengerState messenger,
    SceneImportResult result,
  ) {
    final error = result.error;
    if (error != null) {
      ExportFeedback.showError(messenger, error);
      return;
    }

    final imported =
        '${result.imported} element${result.imported == 1 ? '' : 's'}';
    if (result.dropped == 0) {
      ExportFeedback.showInfo(messenger, 'Imported $imported');
      return;
    }
    // Deliberately the error styling, not the neutral one: a partial import
    // is a problem the user has to know about, and a grey snackbar reads as
    // a confirmation.
    ExportFeedback.showError(
      messenger,
      'Imported $imported — ${result.dropped} could not be read by this '
      'version of FlowCraft and were skipped.',
    );
  }
}
