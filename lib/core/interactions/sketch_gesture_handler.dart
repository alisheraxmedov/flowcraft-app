import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/core/domain/arrow_binding.dart';
import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/core/domain/stroke_simplifier.dart';
import 'package:flowcraft/core/interactions/sketch_drag_session.dart';
import 'package:flowcraft/core/interactions/sketch_interaction_state.dart';
import 'package:flowcraft/core/interactions/sketch_snapping.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
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
    this.snapEnabled = true,
    this.snapThreshold = 6.0,
    this.gridSpacing = AppSpacing.canvasGrid,
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

  /// Whether moves, resizes and endpoint drags snap at all. The per-drag
  /// escape hatch is holding Alt, which is what fine positioning uses;
  /// this flag is for a host that wants snapping off entirely.
  final bool snapEnabled;

  /// Magnet radius in *screen* pixels, converted per event like
  /// [hitTolerance] so it is the same distance under the hand at 0.25x and
  /// at 4x zoom.
  final double snapThreshold;

  /// Spacing of the background grid to snap to, or `null` for element
  /// alignment only.
  ///
  /// Defaults to the same [AppSpacing.canvasGrid] token `GridPainter`
  /// defaults to, so what snaps is what the user can see — there is
  /// deliberately no second copy of that number here.
  ///
  /// Snapping does **not** follow the canvas's grid-visibility toggle. That
  /// toggle is a rendering preference living in the view; snapping is an
  /// editing behaviour. Tying them puts two unrelated preferences on one
  /// switch: you could not hide the dots without losing the magnet, nor get
  /// the magnet without staring at dots. The per-drag Alt override is the
  /// finer-grained control that question actually wants, and alignment
  /// guides keep every snap explained even with the grid hidden. A host
  /// that disagrees passes `null` here.
  final double? gridSpacing;

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

  /// Grab radius for resize / endpoint handles, in *screen* pixels. Wider
  /// than the 8px handles are drawn, because a handle you have to hit
  /// exactly is a handle you miss.
  static const double _handleGrabRadius = 14.0;

  /// Smallest side a resize drag may leave a shape with, in canvas pixels.
  static const double _minResizeSize = 10.0;

  /// Smallest length an endpoint drag may leave a line / arrow with.
  ///
  /// A zero-length line has no direction: its arrowhead points nowhere, and
  /// its hit test collapses onto a single point, so it can never be grabbed
  /// again — the user's only remaining move is undo. The frame is refused
  /// rather than written.
  static const double _minLinearLength = 1.0;

  /// How far from the moving box an element may be and still be offered as
  /// an alignment target, in *screen* pixels. Zoom-converted like every
  /// other radius here, so it always covers roughly the visible window.
  static const double _snapSearchRadius = 800.0;

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
    return (widget.hitTolerance / zoom).clamp(
      _minCanvasHitTolerance,
      _maxCanvasHitTolerance,
    );
  }

  void _setConsumed(bool value) {
    if (_consumed == value) return;
    _consumed = value;
    widget.onConsumedChange?.call(value);
  }

  Offset _toCanvas(Offset screen) =>
      ViewportTransform.screenToCanvas(screen, _viewport);

  void _onPointerDown(PointerDownEvent event) {
    // Only the primary button drives the sketch layer.
    //
    // `Listener` reports every button, so a right- or middle-click used to
    // open a create session and start drawing a rectangle — which on desktop
    // reads as the app being broken, and left nowhere for a canvas context
    // menu to live. The eraser was worse still: it mutates on pointer-down,
    // so a right-click deleted whatever was under the cursor.
    //
    // Neither consuming nor starting anything: the canvas underneath needs
    // these events to keep pan/zoom working, and a swallowed right-click is
    // exactly as wrong as a drawing one.
    //
    // Tested as a mask rather than `==` so a chord (primary held together
    // with another button) still counts as primary. One test covers every
    // input device: the framework normalises a touch or stylus contact to
    // `kPrimaryButton`, and a mouse or trackpad reports the button actually
    // pressed.
    if ((event.buttons & kPrimaryButton) == 0) {
      _setConsumed(false);
      return;
    }

    final tool = _ctrl.currentTool;
    final screen = event.localPosition;
    final canvas = _toCanvas(screen);

    switch (tool) {
      case SketchTool.select:
        final textTarget = _topMostTextTarget(canvas);
        if (textTarget != null && _isDoubleTap(textTarget.id)) {
          _clearTapMemory();
          _collapseStickiesExcept(textTarget.id);
          _beginTextEditOn(textTarget);
          _setConsumed(true);
          return;
        }
        _rememberTap(textTarget?.id);

        // Endpoint handles are tested before bounded-shape handles, so an
        // arrow tip parked on a box's corner still wins. It is the choice
        // that leaves both reachable: a line has these two handles and
        // nothing else, while the box keeps seven other ways to be resized.
        final endpointTarget = _endpointTargetAt(screen);
        // Resolved before the session starts, because the press target is
        // also what decides which open note survives this click. The hit
        // test runs whether or not a handle won, so that a press on a
        // note's own resize handle keeps that note open.
        final resizeTarget = endpointTarget == null
            ? _resizeTargetAt(screen)
            : null;
        final hit = endpointTarget == null && resizeTarget == null
            ? _ctrl.elementAt(canvas, tolerance: _canvasHitTolerance)
            : null;
        _collapseStickiesExcept(
          endpointTarget?.element.id ?? resizeTarget?.element.id ?? hit?.id,
        );

        if (endpointTarget != null) {
          final (:element, :endpoint, :grabbed, :fixed) = endpointTarget;
          _ctrl.beginDragSession();
          _interaction.begin(
            SketchDragSession(
              kind: SketchSessionKind.moveEndpoint,
              startCanvas: canvas,
              startScreen: screen,
              style: _ctrl.currentStyle,
              linearElementId: element.id,
              linearEndpoint: endpoint,
              linearGrabbedPoint: grabbed,
              linearFixedPoint: fixed,
            ),
          );
          _setConsumed(true);
          return;
        }

        if (resizeTarget != null) {
          _ctrl.beginDragSession();
          _interaction.begin(
            SketchDragSession(
              kind: SketchSessionKind.resize,
              startCanvas: canvas,
              startScreen: screen,
              style: _ctrl.currentStyle,
              resizeElementId: resizeTarget.element.id,
              // The stored rect, not the (rotated) canvas box: the resize is
              // written back as the element's `rect`, so it has to start from
              // the same frame or a rotated shape grows by its own AABB.
              resizeStartRect: resizeTarget.element.unrotatedBounds,
              resizeHandle: resizeTarget.handle,
            ),
          );
          _setConsumed(true);
          return;
        }

        final additive = HardwareKeyboard.instance.isShiftPressed;
        if (hit != null) {
          // A group is one object to the pointer, so every path here goes
          // through the whole membership, never the single element hit.
          final group = _ctrl.expandToGroups(<String>[hit.id]);
          if (additive && _ctrl.isSelected(hit.id)) {
            // Shift-clicking something already selected takes it back out —
            // the only way to trim a selection without starting over. No
            // move session follows: the pointer is now over something the
            // drag would no longer be moving.
            for (final id in group) {
              _ctrl.deselect(id);
            }
            _setConsumed(true);
            return;
          }
          if (additive) {
            _ctrl.selectMany(group, clearExisting: false);
          } else if (!_ctrl.isSelected(hit.id)) {
            // Replace only when the click landed outside the selection.
            // Clicking one member of a multi-selection begins a drag of the
            // whole thing; it must not collapse it to the one element first.
            _ctrl.selectMany(group);
          }
          _ctrl.beginDragSession();
          _interaction.begin(
            SketchDragSession(
              kind: SketchSessionKind.moveSelection,
              startCanvas: canvas,
              startScreen: screen,
              style: _ctrl.currentStyle,
              additive: additive,
              moveStartBounds: _selectionBounds(),
              // A press on a collapsed note may turn out to be a click (which
              // opens it) or a drag (which moves it). Which one it was is only
              // knowable at pointer-up, so the candidate rides along on the
              // move session — see `_expandTappedSticky`.
              collapsedStickyId: hit is SketchSticky && hit.collapsed
                  ? hit.id
                  : null,
            ),
          );
          _setConsumed(true);
          return;
        }
        if (!additive) _ctrl.clearSelection();
        _interaction.begin(
          SketchDragSession(
            kind: SketchSessionKind.marquee,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
            additive: additive,
          ),
        );
        _setConsumed(true);
        return;

      case SketchTool.eraser:
        // Erase first: a note under the eraser is gone, and collapsing it
        // on the way would only cost a repaint.
        _eraseAt(canvas);
        _collapseStickiesExcept(null);
        _interaction.begin(
          SketchDragSession(
            kind: SketchSessionKind.erase,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
          ),
        );
        _setConsumed(true);
        return;

      case SketchTool.freedraw:
        _ctrl.clearSelection();
        _collapseStickiesExcept(null);
        _interaction.begin(
          SketchDragSession(
            kind: SketchSessionKind.createFreedraw,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
            tool: tool,
          ),
        );
        _setConsumed(true);
        return;

      case SketchTool.rectangle:
      case SketchTool.ellipse:
      case SketchTool.diamond:
      case SketchTool.triangle:
      case SketchTool.line:
      case SketchTool.arrow:
      case SketchTool.sticky:
      case SketchTool.frame:
        _ctrl.clearSelection();
        // Drawing a new shape is a click outside every open note, the
        // sticky tool included: starting a second note closes the first.
        _collapseStickiesExcept(null);
        _interaction.begin(
          SketchDragSession(
            kind: SketchSessionKind.createBounded,
            startCanvas: canvas,
            startScreen: screen,
            style: _ctrl.currentStyle,
            tool: tool,
          ),
        );
        _setConsumed(true);
        return;

      case SketchTool.text:
        // Text tool: tap on a text-bearing element to edit its label, tap
        // on empty space to create a new free-floating SketchText.
        final target = _topMostTextTarget(canvas);
        _collapseStickiesExcept(target?.id);
        if (target != null) {
          _beginTextEditOn(target);
        } else {
          _ctrl.beginTextEdit(canvasPosition: canvas);
        }
        _setConsumed(true);
        return;

      case SketchTool.icon:
        // A click, not a drag: the glyph has a natural size, so it lands
        // centred under the pointer and the tool stays armed for the next.
        _ctrl.clearSelection();
        _ctrl.add(
          SketchIcon.create(
            rect: Rect.fromCenter(center: canvas, width: 64, height: 64),
            name: _ctrl.currentIcon,
            style: _ctrl.currentStyle,
          ),
        );
        _setConsumed(true);
        return;

      case SketchTool.hand:
        // Pan tool delegates to the underlying canvas.
        //
        // And leaves open notes open: a pan is navigation, not a click on
        // the board — scrolling a conversation does not dismiss the message
        // you were reading. This is also why collapse lives here and not in
        // the canvas widget's own pointer handling, which cannot tell the
        // two apart.
        _setConsumed(false);
        return;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final session = _interaction.session;
    if (session == null) return;

    // A live drag may legitimately *gain* buttons — pressing a second one
    // while the pointer is down delivers a move, not a new down — so the
    // mask is consulted only to spot the primary going up. Releasing it
    // while another button is still held produces no [PointerUpEvent] at
    // all, because the pointer has not left the surface; without this the
    // shape would keep tracking the cursor with nothing pressed and then
    // commit wherever the last button happened to come up.
    //
    // The `!= 0` guard keeps that narrow. Flutter forces `kPrimaryButton`
    // onto touch and stylus events but passes mouse and trackpad masks
    // through exactly as the platform sent them (`_synthesiseDownButtons`
    // in gestures/converter.dart), so a zero mask on a move is a report
    // this code has no interpretation for — and the safe reading of one is
    // "carry on", not "throw away the drag in progress".
    if (event.buttons != 0 && (event.buttons & kPrimaryButton) == 0) {
      _finishSession(session);
      return;
    }

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
        _applyMove(session, canvas);
        break;

      case SketchSessionKind.resize:
        _applyResize(session, canvas);
        break;

      case SketchSessionKind.moveEndpoint:
        _applyEndpointDrag(session, canvas);
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
    _finishSession(session);
  }

  /// Commits [session] and clears the interaction state.
  ///
  /// Shared by [_onPointerUp] and the mid-drag primary-release path in
  /// [_onPointerMove], so a drag ended by lifting the primary button under a
  /// held secondary finishes exactly as one ended by lifting the pointer.
  void _finishSession(SketchDragSession session) {
    switch (session.kind) {
      case SketchSessionKind.createBounded:
        _commitBounded(session);
        break;
      case SketchSessionKind.createFreedraw:
        _commitFreedraw(session);
        break;
      case SketchSessionKind.moveSelection:
        _ctrl.endDragSession();
        _expandTappedSticky(session);
        break;
      case SketchSessionKind.resize:
        _ctrl.endDragSession();
        break;
      case SketchSessionKind.moveEndpoint:
        _rebindEndpoint(session);
        _ctrl.endDragSession();
        break;
      case SketchSessionKind.marquee:
        // A band that never opened up is a click on empty canvas, and that
        // click already did its work on the way down (cleared the
        // selection, closed open notes). Committing the 0×0 rect it left
        // behind selected everything whose *bounding box* held the point —
        // the unfilled frame the hit test had just rejected, plus any
        // freedraw or ellipse whose box happened to cover it — and Delete
        // is one keypress away from there.
        final band = session.currentRect;
        if (!band.isEmpty) {
          _ctrl.selectInRegion(band, addToSelection: session.additive);
          _expandSelectionToGroups();
        }
        break;
      case SketchSessionKind.erase:
      case SketchSessionKind.pan:
        break;
    }

    _interaction.end();
    _setConsumed(false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    // A cancelled drag has to release the controller's drag session too, or
    // `_dragInProgress` stays true with the snapshot it armed: the *next*
    // `beginDragSession` then no-ops against the stale one, and the drag
    // after a cancelled one records no undo entry at all. Desktop cancels
    // for real — losing window focus, or a system gesture taking the
    // pointer — so this is reachable, not theoretical.
    //
    // Guarded on there being a session, because this handler only cleans up
    // what it started: a style-slider drag elsewhere brackets its own
    // begin/endDragSession, and must not be cut in half from here.
    if (_interaction.session != null) _ctrl.endDragSession();
    _interaction.end();
    _setConsumed(false);
  }

  /// Opens the inline editor on [target].
  ///
  /// Shared by the select tool's double-tap-to-edit and the text tool's
  /// tap-to-edit so both agree that a collapsed note has to open first: the
  /// editor lays its glyphs out over the bubble's text box, and a badge does
  /// not have one.
  void _beginTextEditOn(SketchElement target) {
    if (target is SketchSticky && target.collapsed) {
      _ctrl.setStickyCollapsed(target.id, false);
    }
    _ctrl.beginTextEdit(elementId: target.id);
  }

  /// Closes every open sticky note the press did not land on.
  ///
  /// The one rule a user can hold: **a note is open while the pointer is on
  /// it, and a click anywhere else closes it — every time.** Editing is
  /// orthogonal: if that click also ends an edit, the editor's `TapRegion`
  /// commits the text a moment later, and the commit finds the note already
  /// closed. Hanging collapse off the commit alone is how the first version
  /// closed a note exactly once — the second time round there was no edit
  /// to commit, so nothing fired and the bubble stayed put.
  ///
  /// Runs on pointer-**down**, before any session begins, so the board
  /// reacts the instant the button goes down rather than when a marquee
  /// ends — and so the drag snapshot `beginDragSession` arms already holds
  /// the closed state, keeping an undo of the drag from reopening the note.
  ///
  /// "Anywhere else" is anywhere this handler sees. Clicks on app chrome —
  /// the toolbar, the properties panel — never reach the canvas, so a note
  /// stays open through them; the user is doing something else, and the
  /// note can wait for the next click on the board. [keep] is whatever the
  /// press resolved to: the note itself, one of its handles, or `null` for
  /// empty canvas. Another note counts as "elsewhere", so clicking from one
  /// open note to the next closes the first.
  void _collapseStickiesExcept(String? keep) {
    _ctrl.collapseExpandedStickies(except: keep);
  }

  /// Opens a collapsed note that was clicked rather than dragged.
  ///
  /// Deferred to pointer-up, and gated on the move session never having
  /// translated anything: the same press that opens a badge is also the one
  /// that drags it, so acting on pointer-down would make a note impossible
  /// to move without opening it first.
  ///
  /// A single click only *expands* — it does not drop into editing. That
  /// keeps the note consistent with every other text-bearing element on the
  /// canvas, where one click selects and a double-click edits; the second
  /// click of that double then lands on the already-open bubble and takes
  /// the existing double-tap path.
  void _expandTappedSticky(SketchDragSession session) {
    final id = session.collapsedStickyId;
    if (id == null || session.moved) return;
    _ctrl.setStickyCollapsed(id, false);
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

  /// Selected bounded shape whose handle is under [screen], and which of
  /// the eight it is.
  ///
  /// Handle positions come from the *padded* selection box — the same rect
  /// the painter draws them on — via [SketchGeometry.handlePosition], so
  /// grabbing where they look is grabbing where they are.
  ({SketchElement element, ResizeHandle handle})? _resizeTargetAt(
    Offset screen,
  ) {
    final selected = _ctrl.selectedIds;
    if (selected.isEmpty) return null;
    final viewport = _viewport;
    final elements = _ctrl.elements;
    // Topmost first, matching `SketchHitTest.topMost`: where two selected
    // boxes overlap, the one drawn on top owns the handle the user sees.
    for (var i = elements.length - 1; i >= 0; i--) {
      final el = elements[i];
      if (!selected.contains(el.id) || !SketchHitTest.isResizable(el)) {
        continue;
      }
      final box = _selectionBoxOf(el, viewport);
      ResizeHandle? best;
      var bestDistance = double.infinity;
      for (final handle in ResizeHandle.values) {
        final distance =
            (screen - SketchGeometry.handlePosition(box, handle)).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = handle;
        }
      }
      if (best != null && bestDistance <= _handleGrabRadius) {
        return (element: el, handle: best);
      }
    }
    return null;
  }

  /// Selected line / arrow whose endpoint is under [screen].
  ({
    SketchElement element,
    LinearEndpoint endpoint,
    Offset grabbed,
    Offset fixed,
  })?
  _endpointTargetAt(Offset screen) {
    final selected = _ctrl.selectedIds;
    if (selected.isEmpty) return null;
    final viewport = _viewport;
    final elements = _ctrl.elements;
    for (var i = elements.length - 1; i >= 0; i--) {
      final el = elements[i];
      if (!selected.contains(el.id)) continue;
      final ends = SketchGeometry.endpointsOf(el);
      if (ends == null) continue;
      final toStart =
          (screen - ViewportTransform.canvasToScreen(ends.$1, viewport))
              .distance;
      final toEnd =
          (screen - ViewportTransform.canvasToScreen(ends.$2, viewport))
              .distance;
      if (toStart > _handleGrabRadius && toEnd > _handleGrabRadius) continue;
      // Endpoints closer together than the grab radius overlap; the nearer
      // one wins so a near-degenerate line can still be pulled apart, with
      // an exact tie going to `start` for determinism.
      final atStart = toStart <= toEnd;
      return (
        element: el,
        endpoint: atStart ? LinearEndpoint.start : LinearEndpoint.end,
        grabbed: atStart ? ends.$1 : ends.$2,
        fixed: atStart ? ends.$2 : ends.$1,
      );
    }
    return null;
  }

  void _applyMove(SketchDragSession session, Offset canvas) {
    final startBounds = session.moveStartBounds;
    final current = _selectionBounds();
    if (startBounds == null || current == null) return;

    // Resolved against the drag's start, never accumulated frame by frame:
    // folding a snap correction back into a running anchor drifts the
    // selection a little further off on every pointer move.
    final target = startBounds.shift(canvas - session.startCanvas);
    final snap = _snapper()?.resolve(
      moving: target,
      xs: <double>[target.left, target.center.dx, target.right],
      ys: <double>[target.top, target.center.dy, target.bottom],
      // Only the leading edges are offered to the grid — see
      // `SketchSnapper.resolve`.
      gridXs: <double>[target.left],
      gridYs: <double>[target.top],
      candidates: _candidateRects(_ctrl.selectedIds),
    );
    session.guides = snap?.guides ?? const <AlignmentGuide>[];

    final settled = snap == null ? target : target.shift(snap.delta);
    final move = settled.topLeft - current.topLeft;
    if (move != Offset.zero) {
      _ctrl.translateSelected(move);
      // This press has committed to being a drag, so it is no longer the
      // click that would open a collapsed note.
      session.moved = true;
    }
    _interaction.notifyChanged();
  }

  void _applyResize(SketchDragSession session, Offset canvas) {
    final id = session.resizeElementId;
    final start = session.resizeStartRect;
    final handle = session.resizeHandle;
    if (id == null || start == null || handle == null) return;

    // Shift is read live rather than captured at pointer-down, so the ratio
    // can be locked (or released) part-way through a drag.
    final lockAspect =
        handle.isCorner && HardwareKeyboard.instance.isShiftPressed;
    var delta = canvas - session.startCanvas;

    // An aspect lock and a snap are contradictory constraints, and the
    // explicit modifier wins: a locked resize never snaps.
    final snapper = lockAspect ? null : _snapper();
    if (snapper != null) {
      final unsnapped = SketchGeometry.resizeRect(
        start,
        handle,
        delta,
        minSize: _minResizeSize,
      );
      final snap = snapper.resolve(
        moving: unsnapped,
        // Only the edges this handle drives may move, so only they are
        // offered as snap targets.
        xs: <double>[
          if (handle.movesLeft) unsnapped.left,
          if (handle.movesRight) unsnapped.right,
        ],
        ys: <double>[
          if (handle.movesTop) unsnapped.top,
          if (handle.movesBottom) unsnapped.bottom,
        ],
        candidates: _candidateRects(<String>{id}),
      );
      // Fed back through the pointer delta rather than nudging the rect, so
      // the min-size clamp still has the final say.
      delta += snap.delta;
      session.guides = snap.guides;
    } else {
      session.guides = const <AlignmentGuide>[];
    }

    _ctrl.resizeElement(
      id,
      SketchGeometry.resizeRect(
        start,
        handle,
        delta,
        minSize: _minResizeSize,
        preserveAspect: lockAspect,
      ),
    );
    _interaction.notifyChanged();
  }

  void _applyEndpointDrag(SketchDragSession session, Offset canvas) {
    final id = session.linearElementId;
    final grabbed = session.linearGrabbedPoint;
    final fixed = session.linearFixedPoint;
    final which = session.linearEndpoint;
    if (id == null || grabbed == null || fixed == null || which == null) return;

    var point = grabbed + (canvas - session.startCanvas);
    final snap = _snapper()?.resolve(
      moving: Rect.fromCenter(center: point, width: 0, height: 0),
      xs: <double>[point.dx],
      ys: <double>[point.dy],
      candidates: _candidateRects(<String>{id}),
    );
    session.guides = snap?.guides ?? const <AlignmentGuide>[];
    if (snap != null) point += snap.delta;

    if ((point - fixed).distance >= _minLinearLength) {
      _ctrl.updateLinear(
        id,
        start: which == LinearEndpoint.start ? point : null,
        end: which == LinearEndpoint.end ? point : null,
      );
    }
    _interaction.notifyChanged();
  }

  /// The snapper for this pointer move, or `null` while snapping is off.
  ///
  /// Screen-space radii are divided by zoom exactly as [_canvasHitTolerance]
  /// is: a 6px magnet has to stay 6px on the user's screen, not become 24px
  /// of canvas at 4x.
  SketchSnapper? _snapper() {
    if (!widget.snapEnabled) return null;
    // Alt is the escape hatch for fine positioning. Read live, so it can be
    // pressed part-way into a drag that has already snapped.
    if (HardwareKeyboard.instance.isAltPressed) return null;
    final zoom = _viewport.zoom;
    final scale = zoom > 0 ? zoom : 1.0;
    return SketchSnapper(
      threshold: widget.snapThreshold / scale,
      gridSpacing: widget.gridSpacing,
      searchRadius: _snapSearchRadius / scale,
    );
  }

  /// Bounds of every element a drag could align to — one linear pass,
  /// built once per pointer move rather than once per snap candidate.
  List<Rect> _candidateRects(Set<String> exclude) {
    final rects = <Rect>[];
    for (final el in _ctrl.elements) {
      if (exclude.contains(el.id)) continue;
      rects.add(el.bounds);
    }
    return rects;
  }

  /// Union bounds of the current selection, or `null` when nothing is
  /// selected.
  Rect? _selectionBounds() {
    final selected = _ctrl.selectedIds;
    if (selected.isEmpty) return null;
    Rect? union;
    for (final el in _ctrl.elements) {
      if (!selected.contains(el.id)) continue;
      union = union == null ? el.bounds : union.expandToInclude(el.bounds);
    }
    return union;
  }

  /// Pulls the whole of any group the selection touches into it, so click,
  /// shift-click and marquee all agree that a group is a single object.
  void _expandSelectionToGroups() {
    final selected = _ctrl.selectedIds;
    if (selected.isEmpty) return;
    final expanded = _ctrl.expandToGroups(selected);
    if (expanded.length == selected.length) return;
    _ctrl.selectMany(expanded);
  }

  /// [element]'s selection box in screen-space, padded exactly as the
  /// painter pads it.
  static Rect _selectionBoxOf(SketchElement element, FlowViewport viewport) {
    final bounds = element.bounds;
    final tl = ViewportTransform.canvasToScreen(bounds.topLeft, viewport);
    final br = ViewportTransform.canvasToScreen(bounds.bottomRight, viewport);
    return Rect.fromLTRB(
      tl.dx,
      tl.dy,
      br.dx,
      br.dy,
    ).inflate(SketchGeometry.selectionPadding);
  }

  // ── Arrow binding ────────────────────────────────────────────────────────

  /// Cmd (Apple) / Ctrl (others) held at release draws or drops an arrow
  /// without attaching it. Read live, like the wheel-zoom modifier test.
  bool get _bindingSuppressed =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  /// Binding to the bindable shape under [canvas], if any. The tolerance is
  /// the hit radius, so an arrow released just outside an edge still lands.
  SketchBinding? _bindingAt(Offset canvas, {String? exclude}) {
    final target = ArrowBinding.targetAt(
      _ctrl.elements,
      canvas,
      _canvasHitTolerance,
      exclude: exclude,
    );
    return target == null ? null : SketchBinding(elementId: target.id);
  }

  /// After an endpoint drag, attaches the dragged end to the shape it was
  /// released on. `updateLinear` already cleared that end's binding when it
  /// moved, so a still-bound end means a click without movement: left alone,
  /// which also keeps it from re-picking a different overlapping shape.
  void _rebindEndpoint(SketchDragSession session) {
    final id = session.linearElementId;
    final which = session.linearEndpoint;
    if (id == null || which == null || _bindingSuppressed) return;
    final el = _ctrl.elements.where((e) => e.id == id).firstOrNull;
    if (el is! SketchArrow) return;
    final atStart = which == LinearEndpoint.start;
    if ((atStart ? el.startBinding : el.endBinding) != null) return;
    final binding = _bindingAt(atStart ? el.start : el.end, exclude: id);
    if (binding == null) return;
    _ctrl.setArrowBindings(
      id,
      start: atStart ? binding : el.startBinding,
      end: atStart ? el.endBinding : binding,
    );
  }

  // ── Commits ──────────────────────────────────────────────────────────────

  void _commitBounded(SketchDragSession session) {
    final rect = session.currentRect;
    final tool = session.tool;
    if (tool == null) return;

    // A shape needs both axes. `||`, not `&&`: a drag that stayed within a
    // pixel vertically — easy with a mouse on a horizontal pull — used to
    // commit a W×0 rect, which for an ellipse is an empty path: invisible,
    // yet still hit-testable through its stroke band, still counted, still
    // exported.
    final degenerate = rect.width < 1 || rect.height < 1;

    SketchElement? element;
    switch (tool) {
      case SketchTool.rectangle:
        if (degenerate) return;
        element = SketchRectangle.create(rect: rect, style: session.style);
        break;
      case SketchTool.ellipse:
        if (degenerate) return;
        element = SketchEllipse.create(rect: rect, style: session.style);
        break;
      case SketchTool.diamond:
        if (degenerate) return;
        element = SketchDiamond.create(rect: rect, style: session.style);
        break;
      case SketchTool.triangle:
        if (degenerate) return;
        element = SketchTriangle.create(rect: rect, style: session.style);
        break;
      case SketchTool.sticky:
        // No size guard, unlike the shapes above: a note is floored at
        // `SketchSticky.rectFor`'s default rather than discarded, so a plain
        // click drops a note instead of silently doing nothing — which is
        // what a 0×0 drag rect used to do here.
        final sticky = SketchSticky.create(rect: SketchSticky.rectFor(rect));
        _ctrl.add(sticky);
        _ctrl.beginTextEdit(elementId: sticky.id);
        return;
      case SketchTool.frame:
        if (degenerate) return;
        _ctrl.addFrame(
          SketchFrame.create(
            rect: rect,
            name: 'Frame ${_ctrl.elements.whereType<SketchFrame>().length + 1}',
            style: session.style,
          ),
        );
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
        final arrow = SketchArrow.create(
          start: session.startCanvas,
          end: session.currentCanvas,
          style: session.style,
        );
        element = _bindingSuppressed
            ? arrow
            : arrow.copyWith(
                startBinding: _bindingAt(arrow.start),
                endBinding: _bindingAt(arrow.end),
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
    _ctrl.add(SketchFreedraw.create(points: simplified, style: session.style));
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
