import 'dart:ui';

import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/core/interactions/sketch_snapping.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';

/// What kind of work the pointer is currently doing.
enum SketchSessionKind {
  /// Creating a new bounded shape via drag (rect/ellipse/diamond/line/arrow).
  createBounded,

  /// Recording a freedraw stroke.
  createFreedraw,

  /// Translating selected elements.
  moveSelection,

  /// Resizing a single bounded element from one of its eight handles.
  resize,

  /// Moving one endpoint of a line / arrow.
  moveEndpoint,

  /// Rubber-band selection.
  marquee,

  /// Erasing under cursor.
  erase,

  /// Pan (hand tool).
  pan,
}

/// Which end of a linear element an endpoint drag is moving.
enum LinearEndpoint { start, end }

/// Mutable session capturing in-progress pointer work on the sketch layer.
///
/// One session at a time; the gesture handler creates it on pointer-down
/// and discards it on pointer-up. Coordinates are in canvas-space.
class SketchDragSession {
  SketchDragSession({
    required this.kind,
    required this.startCanvas,
    required this.startScreen,
    required this.style,
    this.tool,
    this.resizeElementId,
    this.resizeStartRect,
    this.resizeHandle,
    this.moveStartBounds,
    this.linearElementId,
    this.linearEndpoint,
    this.linearGrabbedPoint,
    this.linearFixedPoint,
    this.additive = false,
    this.collapsedStickyId,
  })  : currentCanvas = startCanvas,
        currentScreen = startScreen,
        freedrawPoints = kind == SketchSessionKind.createFreedraw
            ? <Offset>[startCanvas]
            : null;

  final SketchSessionKind kind;
  final Offset startCanvas;
  final Offset startScreen;
  final SketchStyle style;
  final SketchTool? tool;

  /// Element being resized (for [SketchSessionKind.resize]).
  final String? resizeElementId;

  /// The element's original rect at the start of a resize session.
  final Rect? resizeStartRect;

  /// Which of the eight handles the resize is being driven from.
  final ResizeHandle? resizeHandle;

  /// Union bounds of the selection at the start of a
  /// [SketchSessionKind.moveSelection], in canvas-space.
  ///
  /// A move resolves its position against *this* rather than accumulating
  /// per-frame deltas, because a snap correction folded back into a running
  /// anchor drifts the selection a little further off on every pointer move.
  final Rect? moveStartBounds;

  /// Line / arrow whose endpoint is being dragged.
  final String? linearElementId;

  /// Which endpoint of [linearElementId] the pointer grabbed.
  final LinearEndpoint? linearEndpoint;

  /// Canvas position of the grabbed endpoint when the drag began.
  final Offset? linearGrabbedPoint;

  /// The endpoint that stays put — kept so the degenerate zero-length case
  /// can be rejected without re-reading the element mid-drag.
  final Offset? linearFixedPoint;

  /// Whether the gesture was started with the additive modifier held.
  ///
  /// Captured at pointer-down rather than read at pointer-up: a marquee
  /// applies its result at the *end* of the drag, and releasing shift while
  /// dragging must not quietly turn "add to the selection" into "replace
  /// it".
  final bool additive;

  /// The collapsed sticky note this press landed on, if it landed on one.
  ///
  /// Recorded at pointer-down but acted on at pointer-up, because the same
  /// press is also how a note is dragged: expanding on the way down would
  /// mean every attempt to move a badge opened it first.
  final String? collapsedStickyId;

  Offset currentCanvas;
  Offset currentScreen;

  /// Whether this session has actually moved anything yet.
  ///
  /// The click-versus-drag test, and deliberately not a pointer-distance
  /// threshold: what separates a click from a drag here is whether the drag
  /// did something, which is the same distinction the controller's armed
  /// drag snapshot already uses to decide whether a press earned an undo
  /// entry.
  bool moved = false;

  /// Recorded points for freedraw, in canvas-space.
  final List<Offset>? freedrawPoints;

  /// Guides explaining the snap applied on the last pointer-move, in
  /// canvas-space. Empty whenever the drag is placing freely.
  List<AlignmentGuide> guides = const <AlignmentGuide>[];

  /// Returns the rect spanning [startCanvas]→[currentCanvas], normalised
  /// so width / height are positive.
  Rect get currentRect {
    final left = startCanvas.dx < currentCanvas.dx
        ? startCanvas.dx
        : currentCanvas.dx;
    final top = startCanvas.dy < currentCanvas.dy
        ? startCanvas.dy
        : currentCanvas.dy;
    final right = startCanvas.dx > currentCanvas.dx
        ? startCanvas.dx
        : currentCanvas.dx;
    final bottom = startCanvas.dy > currentCanvas.dy
        ? startCanvas.dy
        : currentCanvas.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
