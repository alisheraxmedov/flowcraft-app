import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/services/canvas_exporter.dart';
import 'package:flowcraft/services/svg_exporter.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';
import 'package:flowcraft/views/widgets/fc_menu.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/import_scene_dialog.dart';
import 'package:flowcraft/views/widgets/paste_scene_dialog.dart';

/// Top-right "Export" control: a menu offering PNG, SVG, JSON, clipboard — and,
/// under a divider, the two ways back in (a file, or pasted JSON).
///
/// Import shares the export button rather than taking a second slot in the
/// top bar because it is the same scene format going the other way: someone
/// looking for "the JSON thing" opens this menu, and a separate control
/// would only be found by people who already knew it existed.
///
/// It owns a busy flag because rendering a large scene to PNG is slow
/// enough that an unresponsive-looking button reads as a broken one, and it
/// self-listens to [controller] so the file options grey out the moment the
/// canvas empties — exporting a blank image is never what was meant.
/// Clipboard stays enabled regardless, since that is the pre-existing
/// behaviour this menu absorbed rather than replaced.
///
/// [documentName] seeds the export filename; the top bar supplies the open
/// project's name through a local `Consumer`.
class ExportMenuButton extends StatefulWidget {
  const ExportMenuButton({
    super.key,
    required this.controller,
    this.documentName,
    this.exportDirectory,
  });

  final SketchController controller;

  /// Seeds the exported filename; falls back to `flowcraft`.
  final String? documentName;

  /// Overrides `~/Documents/FlowCraft`; tests point it at a temp directory.
  final String? exportDirectory;

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
      directoryPath: widget.exportDirectory,
    );
  }

  Future<String> _writeSvg() async {
    final svg = await SvgExporter.render(
      widget.controller.elements,
      background: Theme.of(context).colorScheme.surface,
    );
    return CanvasExporter.writeExport(
      fileName: CanvasExporter.timestampedFileName(_baseName, 'svg'),
      bytes: utf8.encode(svg),
      directoryPath: widget.exportDirectory,
    );
  }

  Future<String> _writeJson() {
    final json = SketchSerializer.serialize(widget.controller.elements);
    return CanvasExporter.writeExport(
      fileName: CanvasExporter.timestampedFileName(_baseName, 'flowcraft.json'),
      // UTF-8, not `codeUnits` — sticky notes and labels routinely carry
      // non-ASCII text that would otherwise be truncated to garbage.
      bytes: utf8.encode(json),
      directoryPath: widget.exportDirectory,
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
          style: fcMenuStyle(context),
          alignmentOffset: const Offset(0, 6),
          menuChildren: [
            FcMenuItem(
              icon: FcIcons.image,
              height: 34,
              onPressed: hasContent ? () => _run(_writePng) : null,
              label: 'Export as PNG',
            ),
            FcMenuItem(
              icon: FcIcons.fileCode,
              height: 34,
              onPressed: hasContent ? () => _run(_writeSvg) : null,
              label: 'Export as SVG',
            ),
            FcMenuItem(
              icon: FcIcons.fileJson,
              height: 34,
              onPressed: hasContent ? () => _run(_writeJson) : null,
              label: 'Export as JSON',
            ),
            FcMenuItem(
              icon: FcIcons.copy,
              height: 34,
              onPressed: _copyJson,
              label: 'Copy JSON to clipboard',
            ),
            // The way back in. It lives under the export routes rather than
            // in a menu of its own because it is the same JSON travelling
            // the other direction -- and because "Export as JSON" promising a
            // re-importable file with no import in the app was the gap.
            const FcMenuDivider(),
            FcMenuItem(
              icon: FcIcons.download,
              height: 34,
              onPressed: () =>
                  ImportSceneDialog.show(context, widget.controller),
              label: 'Import from file…',
            ),
            FcMenuItem(
              icon: FcIcons.clipboard,
              height: 34,
              onPressed: () =>
                  PasteSceneDialog.show(context, widget.controller),
              label: 'Paste JSON, Mermaid, DBML…',
            ),
            const _SavesToNote(),
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

/// Where exports land -- the folder is fixed (no native save dialog; see
/// CLAUDE.md), so the menu says so. Rule above it, 12px muted.
class _SavesToNote extends StatelessWidget {
  const _SavesToNote();

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.glassBorder)),
      ),
      child: Text(
        'Saves to ~/Documents/FlowCraft',
        style: TextStyle(
          fontFamily: AppTypography.geistFamily,
          fontSize: 12,
          color: t.muted,
        ),
      ),
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
    final t = context.fc;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // The only accent-filled control in the chrome; no hover change.
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: busy
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.onAccent,
                        )
                      : FcIconGlyph(
                          FcIcons.upload,
                          size: 16,
                          color: t.onAccent,
                        ),
                ),
                const SizedBox(width: 7),
                Text(
                  busy ? 'Exporting…' : 'Export',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: t.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
