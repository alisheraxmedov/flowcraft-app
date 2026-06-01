import 'package:flutter/widgets.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/sketch/domain/stroke_simplifier.dart';
import 'package:flowcraft/sketch/interactions/sketch_drag_session.dart';
import 'package:flowcraft/sketch/interactions/sketch_interaction_state.dart';
import 'package:flowcraft/sketch/models/sketch_element.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_controller.dart';

/// Returns the current viewport state. Called fresh on each pointer event
/// so the handler always works with up-to-date pan/zoom.
typedef ViewportProvider = FlowViewport Function();

/// Translates pointer events into [SketchController] mutations based on
/// the active [SketchTool].
///
/// Pointer events are observed via [Listener] (translucent), so the
/// underlying canvas remains free to handle pan / zoom when this handler
/// decides not to consume.
class SketchGestureHandler extends StatefulWidget {
  const SketchGestureHandler({
    super.key,
    required this.controller,
    required this.interaction,
    required this.viewportProvider,
    required this.child,
    this.onConsumedChange,
    this.hitTolerance = 8.0,
    this.simplificationTolerance = 0.5,
  });

  final SketchController controller;
  final SketchInteractionState interaction;
  final ViewportProvider viewportProvider;
  final Widget child;
  final ValueChanged<bool>? onConsumedChange;
  final double hitTolerance;
  final double simplificationTolerance;

  @override
  State<SketchGestureHandler> createState() => _SketchGestureHandlerState();
}

class _SketchGestureHandlerState extends State<SketchGestureHandler> {
  bool _consumed = false;

  SketchController get _ctrl => widget.controller;
  SketchInteractionState get _interaction => widget.interaction;
  FlowViewport get _viewport => widget.viewportProvider();

  void _setConsumed(bool value) {
    if (_consumed == value) return;
    _consumed = value;
    widget.onConsumedChange?.call(value);
  }

  Offset _toCanvas(Offset screen) =>
      ViewportTransform.screenToCanvas(screen, _viewport);

  void _onPointerDown(PointerDownEvent event) {
    final tool = _ctrl.currentTool;
    final screen = event.localPosition;
    final canvas = _toCanvas(screen);

    switch (tool) {
      case SketchTool.select:
        final hit = _ctrl.elementAt(canvas, tolerance: widget.hitTolerance);
        if (hit != null) {
          if (!_ctrl.isSelected(hit.id)) {
            _ctrl.select(hit.id);
          }
          _ctrl.beginDragSession();
          _interaction.begin(SketchDragSession(
            kind: SketchSessionKind.moveSelection,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
          ));
          _setConsumed(true);
          return;
        }
        _ctrl.clearSelection();
        _interaction.begin(SketchDragSession(
          kind: SketchSessionKind.marquee,
          startCanvas: canvas,
          startScreen: screen,
          style: _ctrl.currentStyle,
        ));
        _setConsumed(true);
        return;

      case SketchTool.eraser:
        _eraseAt(canvas);
        _interaction.begin(SketchDragSession(
          kind: SketchSessionKind.erase,
          startCanvas: canvas,
          startScreen: screen,
          style: _ctrl.currentStyle,
        ));
        _setConsumed(true);
        return;

      case SketchTool.freedraw:
        _ctrl.clearSelection();
        _interaction.begin(SketchDragSession(
          kind: SketchSessionKind.createFreedraw,
          startCanvas: canvas,
          startScreen: screen,
          style: _ctrl.currentStyle,
          tool: tool,
        ));
        _setConsumed(true);
        return;

      case SketchTool.rectangle:
      case SketchTool.ellipse:
      case SketchTool.diamond:
      case SketchTool.line:
      case SketchTool.arrow:
        _ctrl.clearSelection();
        _interaction.begin(SketchDragSession(
          kind: SketchSessionKind.createBounded,
          startCanvas: canvas,
          startScreen: screen,
          style: _ctrl.currentStyle,
          tool: tool,
        ));
        _setConsumed(true);
        return;

      case SketchTool.text:
        // Text tool: tap on a bounded shape to edit its label, tap on
        // empty space to create a new free-floating SketchText.
        final hit = _ctrl.elementAt(canvas, tolerance: widget.hitTolerance);
        if (hit is SketchRectangle ||
            hit is SketchEllipse ||
            hit is SketchDiamond ||
            hit is SketchText) {
          _ctrl.beginTextEdit(elementId: hit!.id);
        } else {
          _ctrl.beginTextEdit(canvasPosition: canvas);
        }
        _setConsumed(true);
        return;

      case SketchTool.hand:
        // Pan tool delegates to the underlying canvas.
        _setConsumed(false);
        return;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final session = _interaction.session;
    if (session == null) return;

    final screen = event.localPosition;
    final canvas = _toCanvas(screen);
    session.currentCanvas = canvas;
    session.currentScreen = screen;

    switch (session.kind) {
      case SketchSessionKind.createBounded:
        _interaction.notifyChanged();
        break;

      case SketchSessionKind.createFreedraw:
        session.freedrawPoints!.add(canvas);
        _interaction.notifyChanged();
        break;

      case SketchSessionKind.moveSelection:
        final delta = canvas - session.dragAnchorCanvas;
        if (delta == Offset.zero) break;
        _ctrl.translateSelected(delta);
        session.dragAnchorCanvas = canvas;
        break;

      case SketchSessionKind.marquee:
        _interaction.notifyChanged();
        break;

      case SketchSessionKind.erase:
        _eraseAt(canvas);
        break;

      case SketchSessionKind.pan:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final session = _interaction.session;
    if (session == null) {
      _setConsumed(false);
      return;
    }

    switch (session.kind) {
      case SketchSessionKind.createBounded:
        _commitBounded(session);
        break;
      case SketchSessionKind.createFreedraw:
        _commitFreedraw(session);
        break;
      case SketchSessionKind.moveSelection:
        _ctrl.endDragSession();
        break;
      case SketchSessionKind.marquee:
        _ctrl.selectInRegion(session.currentRect);
        break;
      case SketchSessionKind.erase:
      case SketchSessionKind.pan:
        break;
    }

    _interaction.end();
    _setConsumed(false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _interaction.end();
    _setConsumed(false);
  }

  // ── Commits ──────────────────────────────────────────────────────────────

  void _commitBounded(SketchDragSession session) {
    final rect = session.currentRect;
    final tool = session.tool;
    if (tool == null) return;

    SketchElement? element;
    switch (tool) {
      case SketchTool.rectangle:
        if (rect.width < 1 && rect.height < 1) return;
        element = SketchRectangle.create(rect: rect, style: session.style);
        break;
      case SketchTool.ellipse:
        if (rect.width < 1 && rect.height < 1) return;
        element = SketchEllipse.create(rect: rect, style: session.style);
        break;
      case SketchTool.diamond:
        if (rect.width < 1 && rect.height < 1) return;
        element = SketchDiamond.create(rect: rect, style: session.style);
        break;
      case SketchTool.line:
        if ((session.startCanvas - session.currentCanvas).distance < 2) return;
        element = SketchLine.create(
          start: session.startCanvas,
          end: session.currentCanvas,
          style: session.style,
        );
        break;
      case SketchTool.arrow:
        if ((session.startCanvas - session.currentCanvas).distance < 2) return;
        element = SketchArrow.create(
          start: session.startCanvas,
          end: session.currentCanvas,
          style: session.style,
        );
        break;
      case SketchTool.text:
        // Text needs an editor overlay; not committed via gesture.
        return;
      default:
        return;
    }

    _ctrl.add(element);
  }

  void _commitFreedraw(SketchDragSession session) {
    final raw = session.freedrawPoints;
    if (raw == null || raw.length < 2) return;
    final simplified = StrokeSimplifier.simplify(
      raw,
      tolerance: widget.simplificationTolerance,
    );
    _ctrl.add(
      SketchFreedraw.create(points: simplified, style: session.style),
    );
  }

  void _eraseAt(Offset canvas) {
    final hit = _ctrl.elementAt(canvas, tolerance: widget.hitTolerance);
    if (hit != null) {
      _ctrl.remove(hit.id);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
