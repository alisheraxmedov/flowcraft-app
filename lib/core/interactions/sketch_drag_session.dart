import 'dart:ui';

import 'package:flowcraft/models/sketch_element.dart';
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

  /// Resizing a single bounded element from its bottom-right handle.
  resize,

  /// Rubber-band selection.
  marquee,

  /// Erasing under cursor.
  erase,

  /// Pan (hand tool).
  pan,
}

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
  })  : currentCanvas = startCanvas,
        currentScreen = startScreen,
        dragAnchorCanvas = startCanvas,
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

  Offset currentCanvas;
  Offset currentScreen;

  /// Anchor used by [SketchSessionKind.moveSelection] to compute
  /// incremental deltas. Updated on each pointer-move so the next move
  /// reports the delta since the last frame, not since session start.
  Offset dragAnchorCanvas;

  /// Recorded points for freedraw, in canvas-space.
  final List<Offset>? freedrawPoints;

  /// In-progress preview element constructed from the current pointer
  /// position. May be `null` for non-creating sessions.
  SketchElement? previewElement;

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
