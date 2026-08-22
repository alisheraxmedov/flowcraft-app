import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/core/domain/stroke_simplifier.dart';
import 'package:flowcraft/core/interactions/sketch_drag_session.dart';
import 'package:flowcraft/core/interactions/sketch_interaction_state.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

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

  /// Grab radius in *screen* pixels. Converted to canvas-space per event
  /// (see `_canvasHitTolerance`) so it stays constant on screen at any zoom.
  final double hitTolerance;

  final double simplificationTolerance;

  @override
  State<SketchGestureHandler> createState() => _SketchGestureHandlerState();
}

class _SketchGestureHandlerState extends State<SketchGestureHandler> {
  bool _consumed = false;

  /// Last tap bookkeeping for double-tap-to-edit text.
  String? _lastTapElementId;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _doubleTapWindow = Duration(milliseconds: 400);

  /// Guard rails on [_canvasHitTolerance]. Across `FlowViewport`'s own
  /// 0.1–4.0 zoom range the division never reaches either bound; they only
  /// stop a pathological viewport from producing an absurd grab radius.
  static const double _minCanvasHitTolerance = 0.5;
  static const double _maxCanvasHitTolerance = 96.0;

  SketchController get _ctrl => widget.controller;
  SketchInteractionState get _interaction => widget.interaction;
  FlowViewport get _viewport => widget.viewportProvider();

  /// [SketchGestureHandler.hitTolerance] expressed in canvas-space.
  ///
  /// `SketchHitTest` measures in canvas coordinates, so handing it a fixed
  /// number let the grab radius scale with zoom: 4× too generous at 4× zoom
  /// and 4× too mean at 0.25×, i.e. worst precisely when someone has zoomed
  /// in to work carefully. Dividing by zoom keeps it a constant number of
  /// screen pixels, which is what the user's hand actually controls.
  double get _canvasHitTolerance {
    final zoom = _viewport.zoom;
    if (zoom <= 0) return widget.hitTolerance;
    return (widget.hitTolerance / zoom)
        .clamp(_minCanvasHitTolerance, _maxCanvasHitTolerance);
  }

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
        final textTarget = _topMostTextTarget(canvas);
        if (textTarget != null && _isDoubleTap(textTarget.id)) {
          _clearTapMemory();
          _ctrl.beginTextEdit(elementId: textTarget.id);
          _setConsumed(true);
          return;
        }
        _rememberTap(textTarget?.id);

        final resizeTarget = _resizeTargetAt(screen);
        if (resizeTarget != null) {
          _ctrl.beginDragSession();
          _interaction.begin(SketchDragSession(
            kind: SketchSessionKind.resize,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
            resizeElementId: resizeTarget.id,
            resizeStartRect: resizeTarget.bounds,
          ));
          _setConsumed(true);
          return;
        }

        final hit = _ctrl.elementAt(canvas, tolerance: _canvasHitTolerance);
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
      case SketchTool.triangle:
      case SketchTool.line:
      case SketchTool.arrow:
      case SketchTool.sticky:
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
        // Text tool: tap on a text-bearing element to edit its label, tap
        // on empty space to create a new free-floating SketchText.
        final target = _topMostTextTarget(canvas);
        if (target != null) {
          _ctrl.beginTextEdit(elementId: target.id);
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

      case SketchSessionKind.resize:
        _applyResize(session, canvas);
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
      case SketchSessionKind.resize:
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

  /// Shared by both text-edit entry points — the select tool's
  /// double-tap-to-edit and the text tool's tap-to-edit — so they can never
  /// disagree about what counts as "on the text".
  SketchElement? _topMostTextTarget(Offset canvas) =>
      SketchHitTest.topMostTextTarget(
        _ctrl.elements,
        canvas,
        tolerance: _canvasHitTolerance,
      );

  bool _isDoubleTap(String id) {
    if (_lastTapElementId != id) return false;
    return DateTime.now().difference(_lastTapTime) < _doubleTapWindow;
  }

  void _rememberTap(String? id) {
    _lastTapElementId = id;
    _lastTapTime = DateTime.now();
  }

  void _clearTapMemory() {
    _lastTapElementId = null;
    _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  SketchElement? _resizeTargetAt(Offset screen) {
    final selected = _ctrl.selectedIds;
    if (selected.isEmpty) return null;
    final viewport = _viewport;
    for (final el in _ctrl.elements) {
      if (!selected.contains(el.id) || !_isResizable(el)) continue;
      final br = ViewportTransform.canvasToScreen(el.bounds.bottomRight, viewport);
      if ((screen - br).distance <= 14.0) return el;
    }
    return null;
  }

  void _applyResize(SketchDragSession session, Offset canvas) {
    final id = session.resizeElementId;
    final start = session.resizeStartRect;
    if (id == null || start == null) return;

    final delta = canvas - session.startCanvas;
    const minSize = 10.0;
    var right = start.right + delta.dx;
    var bottom = start.bottom + delta.dy;
    if (right < start.left + minSize) right = start.left + minSize;
    if (bottom < start.top + minSize) bottom = start.top + minSize;
    _ctrl.resizeElement(
      id,
      Rect.fromLTRB(start.left, start.top, right, bottom),
    );
  }

  static bool _isResizable(SketchElement e) =>
      e is SketchRectangle ||
      e is SketchEllipse ||
      e is SketchDiamond ||
      e is SketchTriangle ||
      e is SketchSticky;

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
      case SketchTool.triangle:
        if (rect.width < 1 && rect.height < 1) return;
        element = SketchTriangle.create(rect: rect, style: session.style);
        break;
      case SketchTool.sticky:
        if (rect.width < 1 && rect.height < 1) return;
        final sticky = SketchSticky.create(rect: rect);
        _ctrl.add(sticky);
        _ctrl.beginTextEdit(elementId: sticky.id);
        return;
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
    final hit = _ctrl.elementAt(canvas, tolerance: _canvasHitTolerance);
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
