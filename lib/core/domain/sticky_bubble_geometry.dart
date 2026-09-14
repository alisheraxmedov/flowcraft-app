import 'dart:math' as math;
import 'dart:ui';

/// The one place that decides what a sticky note is shaped like.
///
/// A sticky is drawn as a messenger-style chat bubble: a rounded body with a
/// curved tail, or — once collapsed — a rounded badge carrying a miniature
/// outline of that same bubble. Every consumer derives its geometry from
/// here rather than repeating the arithmetic:
///
///  * `SketchSticky.bounds` (what selection, marquee, culling and export see),
///  * `SketchRenderCache` (the fill and the outline, which are one path),
///  * `SketchPainter` (where the label's glyphs go),
///  * `SketchTextEditor` (where the *editable* glyphs go).
///
/// Two of those pairs have already cost this repo a bug when they disagreed —
/// `SketchText.bounds` guessing a width the painter didn't use, and resize
/// handles drawn 4px away from where they were hit-tested. The rule here is
/// the same one `SketchGeometry.handlePosition` encodes: one function, every
/// caller.
///
/// **The bubble is deliberately clean, not rough.** Every other closed shape
/// on the canvas goes through `RoughGenerator`; this one does not. A chat
/// bubble is a clean silhouette in every messenger, and that is what the
/// user asked for. Rendered rough it was a frayed yellow blob: the
/// generator draws square corners (its own documented limitation), so the
/// outline poked past the rounded fill at every corner, and at 40px the
/// wobble turned the badge's mark into a scribble. The hand-drawn register
/// lives in the text and in everything the note annotates.
///
/// Everything below is canvas-space and free of Flutter framework deps, so
/// the model layer can call it without importing rendering.
class StickyBubbleGeometry {
  StickyBubbleGeometry._();

  /// Side of the collapsed badge, in canvas pixels — an app-icon-sized chip,
  /// which is the size the collapsed note is meant to read as. 40 rather
  /// than 36 so the mark inside keeps a legible stroke at 1× zoom.
  static const double collapsedSize = 40.0;

  /// Corner radius of the collapsed badge. Fixed rather than taken from the
  /// element's own `cornerRadius`: the badge is a constant-size chip, so a
  /// radius tuned for a 160px-wide bubble would swallow it whole.
  static const double badgeRadius = 10.0;

  /// Size of the speech-bubble mark inside the badge. A 22×17 bubble is the
  /// proportion the expanded note has at its default size, reduced.
  static const Size glyphSize = Size(22.0, 17.0);

  /// Corner radius of the mark — proportionally a touch rounder than the
  /// note, because at this size a tighter radius reads as a rectangle.
  static const double glyphRadius = 5.5;

  /// Stroke the mark is drawn with, in canvas pixels. Fixed rather than the
  /// element's own `strokeWidth`: the mark is an icon, and an icon whose
  /// line weight followed the user's 6px stroke setting would be a blob.
  static const double glyphStrokeWidth = 2.0;

  /// Nominal height of the tail band reserved along the bottom of a bubble.
  ///
  /// The tail is drawn *inside* the element's rect, not hanging off it. A
  /// tail outside would make `bounds` wider than `rect`, and the gesture
  /// handler seeds a resize from `element.bounds` — so every grab of a handle
  /// would silently grow the note by the tail.
  static const double tailHeight = 9.0;

  /// Nominal width of the tail's base along the bottom edge.
  static const double tailWidth = 16.0;

  /// Horizontal distance from the body's edge to the first glyph. Wider than
  /// the vertical inset, as a messenger bubble's padding is: the text's
  /// left edge must clear the rounded corner, and the eye wants more air on
  /// the reading axis than above and below.
  static const double textInsetX = 12.0;

  /// Vertical distance from the body's edge to the first line.
  static const double textInsetY = 8.0;

  /// The box a sticky actually occupies, which is the box that must be
  /// hit-tested, selected, culled and exported.
  static Rect boundsOf(Rect rect, {required bool collapsed}) =>
      collapsed ? collapsedBounds(rect) : rect;

  /// The collapsed badge, anchored at the expanded bubble's top-left.
  ///
  /// Top-left rather than centred so collapsing and expanding are pure
  /// reversals of each other: the note's origin never moves, `rect` is left
  /// untouched underneath, and expanding restores the exact geometry the
  /// user had — not a default.
  static Rect collapsedBounds(Rect rect) =>
      Rect.fromLTWH(rect.left, rect.top, collapsedSize, collapsedSize);

  /// Height the tail takes out of [rect]. Proportional on a short note so a
  /// bubble resized down to a sliver still has a body left to write in.
  static double tailHeightOf(Rect rect) =>
      math.min(tailHeight, rect.height * 0.28);

  /// Width of the tail's base, capped on a narrow note for the same reason.
  static double tailWidthOf(Rect rect) =>
      math.min(tailWidth, rect.width * 0.35);

  /// The rounded part of the bubble — [rect] minus the tail band.
  static Rect bodyOf(Rect rect) => Rect.fromLTRB(
    rect.left,
    rect.top,
    rect.right,
    rect.bottom - tailHeightOf(rect),
  );

  /// Where the note's text is laid out, by the painter and by the inline
  /// editor alike. They must agree exactly or the glyphs jump the instant
  /// editing starts and jump back on commit.
  static Rect textBoxOf(Rect rect) {
    final body = bodyOf(rect);
    // Never let the insets eat the box: a third of each side keeps a
    // positive-size result for any rect the resize floor can produce.
    final dx = math.min(textInsetX, body.width / 3.0);
    final dy = math.min(textInsetY, body.height / 3.0);
    return Rect.fromLTRB(
      body.left + dx,
      body.top + dy,
      body.right - dx,
      body.bottom - dy,
    );
  }

  /// Height a note needs for its text box to hold [textHeight] of laid-out
  /// text: the text, the vertical insets above and below it, and the tail
  /// band. The inverse of [textBoxOf] for any note tall enough that the
  /// insets and tail are at their nominal sizes — which everything past the
  /// default size is.
  static double heightFor(double textHeight) =>
      textHeight + 2 * textInsetY + tailHeight;

  /// Corner radius the body can actually take, clamped so a large radius on
  /// a small note can't invert the shape.
  static double radiusOf(Rect rect, double cornerRadius) {
    final body = bodyOf(rect);
    return cornerRadius
        .clamp(0.0, math.max(0.0, math.min(body.width, body.height) / 2.0))
        .toDouble();
  }

  /// The bubble as one closed path — rounded body and tail in a single
  /// contour, so the outline the painter strokes is exactly the edge of the
  /// fill it paints. Two separate shapes (a rounded rect plus a triangle)
  /// is what made the tail look bolted on.
  ///
  /// The tail sits at the **bottom-left**. Left, because the note's text is
  /// left-aligned and reads from there, so the bubble's visual anchor and its
  /// reading order agree; and because a left tail is the "received message"
  /// side in every messenger — the neutral, someone-left-a-note reading,
  /// where a right tail says "sent by me". Bottom, because that is where a
  /// tail points on a bubble that sits above what it annotates.
  ///
  /// Its shape is the one messengers converge on: the left edge runs
  /// straight down into the tip, and the bottom edge *scoops* up into the
  /// body — a concave sweep, not a straight triangle side — so the tail
  /// reads as the body curling out rather than as a spike attached to it.
  /// Both control points stay inside [rect], and a quadratic never leaves
  /// the hull of its control points, so neither does the path.
  static Path bubblePath(Rect rect, double cornerRadius) {
    final body = bodyOf(rect);
    final r = radiusOf(rect, cornerRadius);
    final tailH = rect.bottom - body.bottom;
    // The tail's base runs from the rounded corner's end along the bottom
    // edge, clamped so a narrow note's tail still starts and ends on the
    // body instead of crossing the far corner.
    final baseEnd = math.min(body.left + r + tailWidthOf(rect), body.right - r);
    final tip = Offset(rect.left, rect.bottom);

    final path = Path()..moveTo(body.left + r, body.top);
    path.lineTo(body.right - r, body.top);
    _corner(path, Offset(body.right, body.top + r), r);
    path.lineTo(body.right, body.bottom - r);
    _corner(path, Offset(body.right - r, body.bottom), r);
    path.lineTo(baseEnd, body.bottom);
    // Outer edge: from the base, scooping down to the tip. The control
    // point sits *above* the straight chord, which is what makes the sweep
    // concave from outside.
    path.quadraticBezierTo(
      body.left + r * 0.55,
      body.bottom + tailH * 0.35,
      tip.dx,
      tip.dy,
    );
    // Inner edge: from the tip back up into the left side, bulging only
    // slightly so the tail's inner side reads as a continuation of the
    // body's edge.
    path.quadraticBezierTo(
      body.left + r * 0.12,
      body.bottom - r * 0.2,
      body.left,
      body.bottom - r,
    );
    path.lineTo(body.left, body.top + r);
    _corner(path, Offset(body.left + r, body.top), r);
    path.close();
    return path;
  }

  /// Appends a clockwise quarter-circle of radius [r] ending at [to], or a
  /// straight segment when [r] is zero — an arc of zero radius is
  /// undefined, and a sharp corner is what a zero radius asks for anyway.
  static void _corner(Path path, Offset to, double r) {
    if (r <= 0) {
      path.lineTo(to.dx, to.dy);
    } else {
      path.arcToPoint(to, radius: Radius.circular(r));
    }
  }

  /// Filled shape of the collapsed badge.
  static Path badgeFillPath(Rect rect) {
    final badge = collapsedBounds(rect);
    return Path()..addRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(badgeRadius)),
    );
  }

  /// Box the badge's speech-bubble mark is drawn in: [glyphSize], centred.
  static Rect glyphRectOf(Rect rect) => Rect.fromCenter(
    center: collapsedBounds(rect).center,
    width: glyphSize.width,
    height: glyphSize.height,
  );

  /// Outline of the badge's mark — the same bubble silhouette as the
  /// expanded note, in miniature, for the painter to stroke in ink. An
  /// outlined bubble is evocative of a messaging app without reproducing
  /// any product's icon artwork: the shape is this app's own bubble and the
  /// colours are the note's own.
  static Path glyphPath(Rect rect) =>
      bubblePath(glyphRectOf(rect), glyphRadius);
}
