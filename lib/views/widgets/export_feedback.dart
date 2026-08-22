import 'package:flutter/material.dart';

import 'package:flowcraft/services/canvas_exporter.dart';

/// Snackbars for the export flow.
///
/// Every entry point takes a [ScaffoldMessengerState] rather than a
/// [BuildContext]: exports are async, and the button that started one is
/// routinely rebuilt (or disposed) before the write finishes. Resolving the
/// messenger up front keeps the feedback alive across that gap without a
/// `context.mounted` dance at each call site.
class ExportFeedback {
  ExportFeedback._();

  /// Confirms a successful write and offers to select the file in the
  /// platform file manager — the substitute for the native save dialog the
  /// zero-plugin rule rules out.
  static void showSaved(ScaffoldMessengerState messenger, String path) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Saved to $path'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Reveal',
            onPressed: () async {
              final revealed = await CanvasExporter.revealInFileManager(path);
              if (!revealed) {
                showError(messenger, 'Could not open the file manager.');
              }
            },
          ),
        ),
      );
  }

  /// Surfaces the real failure text (permission denied, disk full, …) — an
  /// export that silently does nothing is the bug this menu replaces.
  static void showError(ScaffoldMessengerState messenger, String message) {
    final colorScheme = Theme.of(messenger.context).colorScheme;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          backgroundColor: colorScheme.errorContainer,
          duration: const Duration(seconds: 8),
        ),
      );
  }

  static void showInfo(ScaffoldMessengerState messenger, String message) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
