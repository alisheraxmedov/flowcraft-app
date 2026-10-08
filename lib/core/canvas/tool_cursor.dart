import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

/// Pen and eraser draw their toolbar glyph as the cursor; every other tool
/// gets a system cursor. Flutter has no custom-image cursor without a plugin,
/// so the glyph is an overlay that follows the pointer and the system cursor
/// is hidden. Pointer moves only touch the overlay, never the canvas below.
class ToolCursorLayer extends StatefulWidget {
  const ToolCursorLayer({
    super.key,
    required this.controller,
    required this.child,
  });

  final SketchController controller;
  final Widget child;

  /// Logical size of the cursor glyph.
  static const double glyphSize = 22;

  /// Where the writing tip / erasing edge sits in the glyph's 24-unit
  /// viewBox: pencil tip is the path's `2 22` point, the eraser touches the
  /// surface at its `7 21` corner on the baseline.
  static const Offset pencilHotspot = Offset(2, 22);
  static const Offset eraserHotspot = Offset(7, 21);

  static FcIcon? glyphFor(SketchTool tool) => switch (tool) {
    SketchTool.freedraw => FcIcons.pencil,
    SketchTool.eraser => FcIcons.eraser,
    _ => null,
  };

  static Offset hotspotFor(SketchTool tool) =>
      tool == SketchTool.eraser ? eraserHotspot : pencilHotspot;

  static MouseCursor cursorFor(SketchTool tool, {bool dragging = false}) =>
      switch (tool) {
        SketchTool.select => SystemMouseCursors.basic,
        SketchTool.hand =>
          dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        SketchTool.text => SystemMouseCursors.text,
        SketchTool.freedraw || SketchTool.eraser => SystemMouseCursors.none,
        _ => SystemMouseCursors.precise,
      };

  @override
  State<ToolCursorLayer> createState() => _ToolCursorLayerState();
}

// Wider copies of the glyph, painted underneath as a contrast halo.
final _halos = {
  FcIcons.pencil: FcIcon('pencil-halo', FcIcons.pencil.shapes, strokeWidth: 4),
  FcIcons.eraser: FcIcon('eraser-halo', FcIcons.eraser.shapes, strokeWidth: 4),
};

class _ToolCursorLayerState extends State<ToolCursorLayer> {
  final ValueNotifier<Offset?> _pos = ValueNotifier(null);
  late SketchTool _tool = widget.controller.currentTool;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(ToolCursorLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _onController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _pos.dispose();
    super.dispose();
  }

  void _onController() {
    if (widget.controller.currentTool == _tool) return;
    setState(() {
      _tool = widget.controller.currentTool;
      _dragging = false;
    });
  }

  void _move(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse) _pos.value = e.localPosition;
  }

  void _setDragging(bool v) {
    if (_dragging != v && _tool == SketchTool.hand) {
      setState(() => _dragging = v);
    } else {
      _dragging = v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyph = ToolCursorLayer.glyphFor(_tool);
    return MouseRegion(
      cursor: ToolCursorLayer.cursorFor(_tool, dragging: _dragging),
      onExit: (_) => _pos.value = null,
      child: Listener(
        onPointerHover: _move,
        onPointerMove: _move,
        onPointerDown: (_) => _setDragging(true),
        onPointerUp: (_) => _setDragging(false),
        onPointerCancel: (_) => _setDragging(false),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (glyph != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<Offset?>(
                      valueListenable: _pos,
                      builder: (context, p, _) {
                        if (p == null) return const SizedBox.shrink();
                        final fc = context.fc;
                        final hot =
                            ToolCursorLayer.hotspotFor(_tool) *
                            (ToolCursorLayer.glyphSize / glyph.width);
                        return Stack(
                          children: [
                            Positioned(
                              key: const ValueKey('tool-cursor-glyph'),
                              left: p.dx - hot.dx,
                              top: p.dy - hot.dy,
                              child: Stack(
                                children: [
                                  FcIconGlyph(
                                    _halos[glyph]!,
                                    size: ToolCursorLayer.glyphSize,
                                    color: fc.bg,
                                  ),
                                  FcIconGlyph(
                                    glyph,
                                    size: ToolCursorLayer.glyphSize,
                                    color: fc.text,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
