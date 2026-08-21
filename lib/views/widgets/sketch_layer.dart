import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/interactions/sketch_gesture_handler.dart';
import 'package:flowcraft/core/theme/app_colors.dart';
import 'package:flowcraft/core/interactions/sketch_interaction_state.dart';
import 'package:flowcraft/core/rendering/sketch_painter.dart';
import 'package:flowcraft/core/rendering/sketch_preview_painter.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/sketch_text_editor.dart';

/// Drop-in widget rendering the sketch (drawing) layer.
///
/// Compose this over a [FlowCanvas] (or any widget) by wrapping it in a
/// [Stack]. The layer:
///
///  * subscribes to [controller] for element / selection changes,
///  * subscribes to its internal [SketchInteractionState] for live preview
///    updates while the user draws,
///  * owns a persistent [SketchRenderCache] across rebuilds so generated
///    rough/sketchy paths are reused instead of recomputed every frame,
///  * routes pointer events through [SketchGestureHandler] so the active
///    tool drives creation / selection / erase behaviour.
class SketchLayer extends StatefulWidget {
  const SketchLayer({
    super.key,
    required this.controller,
    required this.viewportProvider,
    this.selectionColor = AppColors.primary,
    this.marqueeColor = AppColors.primary,
    // Downstream of the user's own sketch style, not chrome — mirrors
    // `SketchStyle`'s / the toolbar palette's default stroke color, and is
    // overridden with the live `currentStyle.strokeColor` wherever this
    // widget is actually wired up (see the text-editor build below).
    this.previewColor = const Color(0xFF1E1E1E),
    this.scaleStrokeWithZoom = true,
    this.onConsumedChange,
  });

  final SketchController controller;
  final ViewportProvider viewportProvider;
  final Color selectionColor;
  final Color marqueeColor;
  final Color previewColor;
  final bool scaleStrokeWithZoom;

  /// Notifies whenever the sketch layer starts/stops consuming pointer
  /// events. Hosts may use this to suppress competing gesture handlers
  /// during an in-progress sketch interaction.
  final ValueChanged<bool>? onConsumedChange;

  @override
  State<SketchLayer> createState() => _SketchLayerState();
}

class _SketchLayerState extends State<SketchLayer> {
  final SketchRenderCache _cache = SketchRenderCache();
  final SketchInteractionState _interaction = SketchInteractionState();

  @override
  void dispose() {
    _interaction.dispose();
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SketchGestureHandler(
      controller: widget.controller,
      interaction: _interaction,
      viewportProvider: widget.viewportProvider,
      onConsumedChange: widget.onConsumedChange,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: SketchPainter(
                    elements: widget.controller.elements,
                    selectedIds: widget.controller.selectedIds,
                    viewport: widget.viewportProvider(),
                    paintGen: widget.controller.paintGen,
                    cache: _cache,
                    selectionColor: widget.selectionColor,
                    editingElementId: widget.controller.editingElementId,
                    scaleStrokeWithZoom: widget.scaleStrokeWithZoom,
                  ),
                );
              },
            ),
          ),
          RepaintBoundary(
            child: ListenableBuilder(
              listenable: _interaction,
              builder: (context, _) {
                return CustomPaint(
                  painter: SketchPreviewPainter(
                    session: _interaction.session,
                    revision: _interaction.revision,
                    viewport: widget.viewportProvider(),
                    marqueeColor: widget.marqueeColor,
                    previewColor: widget.previewColor,
                  ),
                );
              },
            ),
          ),
          // Inline text editor — visible only while the controller has
          // an active edit target.
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              if (widget.controller.editingElementId == null &&
                  widget.controller.editingCanvasPosition == null) {
                return const SizedBox.shrink();
              }
              return SketchTextEditor(
                controller: widget.controller,
                viewport: widget.viewportProvider(),
                textColor: widget.controller.currentStyle.strokeColor,
                cursorColor: widget.selectionColor,
              );
            },
          ),
        ],
      ),
    );
  }
}
