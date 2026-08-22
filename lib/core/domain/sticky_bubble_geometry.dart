import 'dart:math' as math;
import 'dart:ui';

/// The one place that decides what a sticky note is shaped like.
///
/// A sticky is drawn as a messenger-style chat bubble: a rounded body with a
/// small tail, or — once collapsed — a rounded badge carrying a miniature
/// speech-bubble mark. Every consumer derives its geometry from here rather
/// than repeating the arithmetic:
///
///  * `SketchSticky.bounds` (what selection, marquee, culling and export see),
///  * `SketchRenderCache` (the rough stroke and the exact fill),
///  * `SketchPainter` (where the label's glyphs go),
///  * `SketchTextEditor` (where the *editable* glyphs go).
///
/// Two of those pairs have already cost this repo a bug when they disagreed —
/// `SketchText.bounds` guessing a width the painter didn't use, and resize
/// handles drawn 4px away from where they were hit-tested. The rule here is
/// the same one `SketchGeometry.handlePosition` encodes: one function, every
/// caller.
///
/// Everything below is canvas-space and free of Flutter framework deps, so
/// the model layer can call it without importing rendering.
class StickyBubbleGeometry {
  StickyBubbleGeometry._();

  /// Side of the collapsed badge, in canvas pixels — roughly an app icon,
  /// which is the size the collapsed note is meant to read as.
  static const double collapsedSize = 36.0;

  /// Nominal height of the tail band reserved along the bottom of a bubble.
  ///
  /// The tail is drawn *inside* the element's rect, not hanging off it. A
  /// tail outside would make `bounds` wider than `rect`, and the gesture
  /// handler seeds a resize from `element.bounds` — so every grab of a handle
  /// would silently grow the note by the tail.
  static const double tailHeight = 10.0;

  /// Nominal width of the tail's base.
  static const double tailWidth = 14.0;

  /// Distance from the bubble body's edge to its first glyph.
  static const double textInset = 8.0;

  /// Distance from the collapsed badge's edge to its speech-bubble mark.
  static const double glyphInset = 8.0;

  /// Corner radius of the collapsed badge. Fixed rather than taken from the
  /// element's own `cornerRadius`: the badge is a constant-size chip, so a
  /// radius tuned for a 160px-wide bubble would swallow it whole.
  static const double badgeRadius = 10.0;

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
    // Never let the inset eat the box: a third of the shorter side keeps a
    // positive-width result for any rect the resize floor can produce.
    final inset =
        math.min(textInset, math.min(body.width, body.height) / 3.0);
    return Rect.fromLTRB(
      body.left + inset,
      body.top + inset,
      body.right - inset,
      body.bottom - inset,
    );
  }

  /// Corner radius the body can actually take, clamped so a large radius on
  /// a small note can't invert the shape.
  static double radiusOf(Rect rect, double cornerRadius) {
    final body = bodyOf(rect);
    return cornerRadius
        .clamp(0.0, math.max(0.0, math.min(body.width, body.height) / 2.0))
        .toDouble();
  }

  /// Outline of the bubble as a closed polygon, walked clockwise from the
  /// body's top-left.
  ///
  /// The tail sits at the **bottom-left**. Left, because the note's text is
  /// left-aligned and reads from there, so the bubble's visual anchor and its
  /// reading order agree; and because a left tail is the "received message"
  /// side in every messenger — the neutral, someone-left-a-note reading,
  /// where a right tail says "sent by me". Bottom, because that is where a
  /// tail points on a bubble that sits above what it annotates.
  ///
  /// Corners are square here. `RoughGenerator` renders rounded corners as
  /// square ones for [RoughGenerator.rectangle] too — the roughness dominates
  /// the silhouette — while [fillPath] below carries the real rounding.
  static List<Offset> outlineVertices(Rect rect, double cornerRadius) {
    final body = bodyOf(rect);
    final radius = radiusOf(rect, cornerRadius);
    final tailW = tailWidthOf(rect);
    // The tail springs from just past the rounded bottom-left corner, and
    // its base is clamped inside the body so a narrow note keeps a tail that
    // still starts and ends on the bubble.
    final baseStart = math.min(body.left + radius, body.right);
    final baseEnd = math.min(baseStart + tailW, body.right);
    return <Offset>[
      body.topLeft,
      body.topRight,
      body.bottomRight,
      Offset(baseEnd, body.bottom),
      // Apex: straight down from the body's bottom-left, giving the swept
      // tail a vertical inner edge and a sloped outer one.
      Offset(rect.left, rect.bottom),
      body.bottomLeft,
    ];
  }

  /// The bubble as a filled, exactly-rounded shape: body plus tail.
  ///
  /// Two subpaths under the default non-zero fill rule, which unions them —
  /// cheaper and more robust than stitching arcs and lines into one contour.
  static Path fillPath(Rect rect, double cornerRadius) {
    final body = bodyOf(rect);
    final radius = radiusOf(rect, cornerRadius);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));

    final tailW = tailWidthOf(rect);
    final baseStart = math.min(body.left + radius, body.right);
    final baseEnd = math.min(baseStart + tailW, body.right);
    if (baseEnd > body.left && rect.bottom > body.bottom) {
      path
        ..moveTo(body.left, body.bottom)
        ..lineTo(baseEnd, body.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
    }
    return path;
  }

  /// Filled shape of the collapsed badge.
  static Path badgeFillPath(Rect rect) {
    final badge = collapsedBounds(rect);
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(badge, const Radius.circular(badgeRadius)),
      );
  }

  /// Box the badge's speech-bubble mark is drawn in.
  static Rect glyphRectOf(Rect rect) =>
      collapsedBounds(rect).deflate(glyphInset);

  /// Outline of the badge's mark — the same bubble silhouette as the
  /// expanded note, in miniature. Evocative of a messaging app rather than a
  /// copy of any product's icon: the shape is this app's own bubble, and the
  /// colours are the note's own.
  static List<Offset> glyphVertices(Rect rect) {
    final glyph = glyphRectOf(rect);
    // A radius proportional to the mark, so it reads as a bubble and not as
    // a rectangle with a spike.
    return outlineVertices(glyph, glyph.shortestSide * 0.3);
  }
}
