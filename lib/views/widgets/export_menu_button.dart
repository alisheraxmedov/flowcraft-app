import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/services/canvas_exporter.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';

/// Top-bar "Export" control: a menu offering PNG, JSON, and clipboard.
///
/// It owns a busy flag because rendering a large scene to PNG is slow
/// enough that an unresponsive-looking button reads as a broken one, and it
/// self-listens to [controller] so the file options grey out the moment the
/// canvas empties — exporting a blank image is never what was meant.
/// Clipboard stays enabled regardless, since that is the pre-existing
/// behaviour this menu absorbed rather than replaced.
///
/// Wiring — in `whiteboard_view.dart`'s `_TopBarState.build()`, replace
/// `_ExportButton(onTap: _export)` with:
///
/// ```dart
/// ExportMenuButton(controller: ctrl),
/// ```
///
/// To name exported files after the open project, wrap it in a `Consumer`
/// (`_TopBar` is a plain `StatefulWidget`, so it has no `ref` of its own):
///
/// ```dart
/// Consumer(
///   builder: (context, ref, _) => ExportMenuButton(
///     controller: ctrl,
///     documentName: ref.watch(projectsViewModelProvider).active?.name,
///   ),
/// ),
/// ```
///
/// The old `_ExportButton` class and `_TopBarState._export` become dead
/// once that swap is made, along with that file's `Clipboard` and
/// `SketchSerializer` imports.
class ExportMenuButton extends StatefulWidget {
  const ExportMenuButton({
    super.key,
    required this.controller,
    this.documentName,
  });

  final SketchController controller;

  /// Seeds the exported filename; falls back to `flowcraft`.
  final String? documentName;

  @override
  State<ExportMenuButton> createState() => _ExportMenuButtonState();
}

class _ExportMenuButtonState extends State<ExportMenuButton> {
  bool _busy = false;

  String get _baseName => widget.documentName ?? 'flowcraft';

  /// Runs one export job behind a busy flag, turning any failure into a
  /// visible snackbar. The messenger is resolved before the first `await`
  /// because a long PNG render can outlive this element.
  Future<void> _run(Future<String> Function() job) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      ExportFeedback.showSaved(messenger, await job());
    } catch (error) {
      ExportFeedback.showError(messenger, 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _writePng() async {
    final background = Theme.of(context).colorScheme.surface;
    final bytes = await CanvasExporter.renderPng(
      widget.controller.elements,
      background: background,
    );
    return CanvasExporter.writeExport(
      fileName: CanvasExporter.timestampedFileName(_baseName, 'png'),
      bytes: bytes,
    );
  }

  Future<String> _writeJson() {
    final json = SketchSerializer.serialize(widget.controller.elements);
    return CanvasExporter.writeExport(
      fileName: CanvasExporter.timestampedFileName(_baseName, 'flowcraft.json'),
      // UTF-8, not `codeUnits` — sticky notes and labels routinely carry
      // non-ASCII text that would otherwise be truncated to garbage.
      bytes: utf8.encode(json),
    );
  }

  Future<void> _copyJson() async {
    final elements = widget.controller.elements;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Awaited: the platform channel can reject, and reporting "Copied!"
      // over a clipboard that stayed empty is the silent failure this menu
      // exists to stop.
      await Clipboard.setData(
        ClipboardData(text: SketchSerializer.serialize(elements)),
      );
      ExportFeedback.showInfo(
        messenger,
        'Copied ${elements.length} element'
        '${elements.length == 1 ? '' : 's'} as JSON',
      );
    } catch (error) {
      ExportFeedback.showError(messenger, 'Copy failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final hasContent = widget.controller.elements.isNotEmpty;
        return MenuAnchor(
          alignmentOffset: const Offset(0, AppSpacing.toolbarGap),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.image_outlined, size: 18),
              onPressed: hasContent ? () => _run(_writePng) : null,
              child: const Text('Export as PNG'),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.data_object_rounded, size: 18),
              onPressed: hasContent ? () => _run(_writeJson) : null,
              child: const Text('Export as JSON'),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.copy_all_rounded, size: 18),
              onPressed: _copyJson,
              child: const Text('Copy JSON to clipboard'),
            ),
          ],
          builder: (context, menu, _) => _ExportPill(
            busy: _busy,
            onTap: _busy
                ? null
                : () => menu.isOpen ? menu.close() : menu.open(),
          ),
        );
      },
    );
  }
}

/// The button itself. Visually identical to the pill it replaces; only the
/// icon swaps for a spinner while a render/write is in flight, because a
/// large scene takes long enough that a dead-looking button reads as a bug.
class _ExportPill extends StatelessWidget {
  const _ExportPill({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary,
      borderRadius: AppRadius.xsRadius,
      child: InkWell(
        borderRadius: AppRadius.xsRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 16,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      )
                    : Icon(
                        Icons.ios_share_rounded,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
              ),
              const SizedBox(width: 6),
              Text(
                busy ? 'Exporting…' : 'Export',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
