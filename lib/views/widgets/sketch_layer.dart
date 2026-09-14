import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/interactions/sketch_gesture_handler.dart';
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
///    rough/sketchy paths and laid-out labels are reused instead of
///    recomputed every frame,
///  * routes pointer events through [SketchGestureHandler] so the active
///    tool drives creation / selection / erase behaviour.
///
/// The in-progress preview takes its colour, width and pattern from the
/// drag session's own `SketchStyle` — the style the element will be
/// committed with — so the rubber-band shape is the shape the user is
/// about to get, in the colour they picked, in light and dark chrome alike.
class SketchLayer extends StatefulWidget {
  const SketchLayer({
    super.key,
    required this.controller,
    required this.viewportProvider,
    this.selectionColor,
    this.marqueeColor,
    this.scaleStrokeWithZoom = true,
    this.onConsumedChange,
  });

  final SketchController controller;
  final ViewportProvider viewportProvider;

  /// Colour of selection boxes and handles. Resolves to the ambient
  /// `colorScheme.primary` when not given, so the chrome follows the theme
  /// rather than a fixed brand token.
  final Color? selectionColor;

  /// Colour of the marquee band and snap guides. Resolves like
  /// [selectionColor].
  final Color? marqueeColor;

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
    // The cache owns native text layouts, not just paths.
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final selectionColor = widget.selectionColor ?? primary;
    final marqueeColor = widget.marqueeColor ?? primary;
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
                    selectionColor: selectionColor,
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
                    marqueeColor: marqueeColor,
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
                cursorColor: selectionColor,
              );
            },
          ),
        ],
      ),
    );
  }
}
