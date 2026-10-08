import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flowcraft/core/domain/elbow_router.dart';
import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_style.dart';

/// Base for any drawable element on the sketch layer.
///
/// All elements are immutable value types. Mutating an element returns
/// a new instance via [copyWith] or a per-subclass helper.
///
/// Coordinates are in canvas-space (not screen-space).
sealed class SketchElement {
  const SketchElement({
    required this.id,
    required this.style,
    this.angle = 0.0,
    this.groupId,
  });

  final String id;
  final SketchStyle style;

  /// Rotation in radians, around the centre of [bounds].
  ///
  /// Reserved: no tool sets it yet, so it is `0.0` for every element a user
  /// can make, and it is kept in the schema for the same reason
  /// [SketchBinding] is — a field that first appears in a later release
  /// makes every v1 file forward-incompatible. It is honoured consistently
  /// where it does appear (a hand-edited or MCP file): the painter rotates
  /// the element, [bounds] is the box of the *rotated* element, and the hit
  /// tests unrotate the pointer into the element's own frame. What is not
  /// rotation-aware is editing — resize handles and endpoint drags work on
  /// the stored geometry as if [angle] were zero.
  final double angle;

  /// Group this element belongs to, or `null` when it stands alone.
  ///
  /// Groups are flat — an element is in one group or none, and nesting is
  /// deliberately not modelled. Every transform below preserves it, because
  /// a group that dissolves the moment it is dragged is worse than no
  /// grouping at all.
  final String? groupId;

  /// Axis-aligned bounding box in canvas-space of the element *as drawn* —
  /// that is, after [angle].
  ///
  /// This is what culling, marquee selection, selection boxes, snapping and
  /// export reason about, so it has to enclose what the painter puts on
  /// screen. For the unrotated case (every element today) it is exactly
  /// [unrotatedBounds], returned as the same instance so per-element caches
  /// behind that getter are not defeated here.
  Rect get bounds {
    final local = unrotatedBounds;
    if (angle == 0.0) return local;
    return _rotatedAabb(local, angle);
  }

  /// The element's box in its own frame, before [angle] is applied.
  ///
  /// The rect the painter draws into under its rotation transform and the
  /// one the hit tests unrotate the pointer into. Its centre is the pivot,
  /// which is also the centre of [bounds].
  Rect get unrotatedBounds;

  SketchElement copyWithStyle(SketchStyle newStyle);
  SketchElement translate(Offset delta);

  /// Copy of this element under a different [id].
  ///
  /// [id] is `final`, so duplicate and paste need this to mint distinct
  /// elements: two elements sharing an id give selection, hit-testing and
  /// MCP addressing the same handle for both.
  SketchElement withId(String id);

  /// Copy of this element in group [groupId]; `null` ungroups it.
  SketchElement withGroupId(String? groupId);

  Map<String, dynamic> toJson();

  static SketchElement fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'rectangle':
        return SketchRectangle.fromJson(json);
      case 'ellipse':
        return SketchEllipse.fromJson(json);
      case 'diamond':
        return SketchDiamond.fromJson(json);
      case 'triangle':
        return SketchTriangle.fromJson(json);
      case 'sticky':
        return SketchSticky.fromJson(json);
      case 'line':
        return SketchLine.fromJson(json);
      case 'arrow':
        return SketchArrow.fromJson(json);
      case 'freedraw':
        return SketchFreedraw.fromJson(json);
      case 'text':
        return SketchText.fromJson(json);
      case 'frame':
        return SketchFrame.fromJson(json);
      case 'icon':
        return SketchIcon.fromJson(json);
      case 'image':
        return SketchImage.fromJson(json);
      case 'entity':
        return SketchEntity.fromJson(json);
      default:
        throw StateError('Unknown sketch element type: $type');
    }
  }
}

// ─── Bounded shapes (rect/ellipse/diamond) ─────────────────────────────────

/// Shared base for shapes defined by an axis-aligned [Rect].
///
/// Bounded shapes can optionally carry a centred text label rendered on
/// top of their stroke. [text] is null for plain shapes; assign via the
/// per-subclass `copyWith(text: ...)`.
sealed class _SketchBoundedShape extends SketchElement {
  const _SketchBoundedShape({
    required super.id,
    required super.style,
    required this.rect,
    this.text,
    this.fontSize = 16.0,
    this.fontFamily,
    this.bold = false,
    super.angle,
    super.groupId,
  });

  final Rect rect;
  final String? text;
  final double fontSize;

  /// `'sans'`, `'mono'` or `null` for the canvas default; see
  /// `TextMetrics.resolveFontFamily`.
  final String? fontFamily;
  final bool bold;

  @override
  Rect get unrotatedBounds => rect;
}

class SketchRectangle extends _SketchBoundedShape {
  const SketchRectangle({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.fontFamily,
    super.bold,
    this.cornerRadius = 0.0,
    super.angle,
    super.groupId,
  });

  /// Reserved — not rendered in v1.
  ///
  /// Parsed and written back so a file that carries it keeps it, but the
  /// rough generator draws square corners regardless, nothing in the UI
  /// sets it, and the hit test is the sharp [rect]. Kept in the schema so
  /// that rounding can ship later without a format bump.
  final double cornerRadius;

  SketchRectangle copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? cornerRadius,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    Object? groupId = _unset,
  }) {
    return SketchRectangle(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchRectangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchRectangle translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchRectangle withId(String id) => copyWith(id: id);

  @override
  SketchRectangle withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchRectangle.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    double cornerRadius = 0.0,
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchRectangle(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      cornerRadius: cornerRadius,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'rectangle',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'cornerRadius': cornerRadius,
    'angle': angle,
    if (text != null) 'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchRectangle.fromJson(Map<String, dynamic> json) {
    return SketchRectangle(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      cornerRadius: _cornerRadiusFromJson(json, fallback: 0.0),
      angle: _angleFromJson(json),
      text: json['text'] as String?,
      fontSize: _fontSizeFromJson(json, fallback: 16.0),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchEllipse extends _SketchBoundedShape {
  const SketchEllipse({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.fontFamily,
    super.bold,
    super.angle,
    super.groupId,
  });

  SketchEllipse copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    Object? groupId = _unset,
  }) {
    return SketchEllipse(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchEllipse copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchEllipse translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchEllipse withId(String id) => copyWith(id: id);

  @override
  SketchEllipse withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchEllipse.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchEllipse(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ellipse',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'angle': angle,
    if (text != null) 'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchEllipse.fromJson(Map<String, dynamic> json) {
    return SketchEllipse(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: _angleFromJson(json),
      text: json['text'] as String?,
      fontSize: _fontSizeFromJson(json, fallback: 16.0),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchDiamond extends _SketchBoundedShape {
  const SketchDiamond({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.fontFamily,
    super.bold,
    super.angle,
    super.groupId,
  });

  SketchDiamond copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    Object? groupId = _unset,
  }) {
    return SketchDiamond(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchDiamond copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchDiamond translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchDiamond withId(String id) => copyWith(id: id);

  @override
  SketchDiamond withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchDiamond.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchDiamond(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'diamond',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'angle': angle,
    if (text != null) 'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchDiamond.fromJson(Map<String, dynamic> json) {
    return SketchDiamond(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: _angleFromJson(json),
      text: json['text'] as String?,
      fontSize: _fontSizeFromJson(json, fallback: 16.0),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchTriangle extends _SketchBoundedShape {
  const SketchTriangle({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.fontFamily,
    super.bold,
    super.angle,
    super.groupId,
  });

  SketchTriangle copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    Object? groupId = _unset,
  }) {
    return SketchTriangle(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchTriangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchTriangle translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchTriangle withId(String id) => copyWith(id: id);

  @override
  SketchTriangle withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchTriangle.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchTriangle(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'triangle',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'angle': angle,
    if (text != null) 'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchTriangle.fromJson(Map<String, dynamic> json) {
    return SketchTriangle(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: _angleFromJson(json),
      text: json['text'] as String?,
      fontSize: _fontSizeFromJson(json, fallback: 16.0),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchSticky extends _SketchBoundedShape {
  const SketchSticky({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize = defaultFontSize,
    super.fontFamily,
    super.bold,
    super.angle,
    super.groupId,
    this.cornerRadius = defaultCornerRadius,
    this.collapsed = false,
  });

  /// Default sticky-note paper colour.
  ///
  /// A saturated amber rather than the pale Excalidraw yellow it replaced.
  /// The note is drawn as a messenger bubble, and a messenger's bubble is a
  /// *coloured* container — against a near-white canvas the pale wash read
  /// as a stain, not a surface, and beside the board's black-stroked shapes
  /// it had no presence at all. Nothing else on the canvas casts a shadow,
  /// so a stronger fill is how the bubble earns its edge.
  static const Color defaultColor = Color(0xFFFFD54F);

  /// Default outline colour: the paper, darkened. A hairline in a deeper
  /// shade is what gives the bubble a crisp edge on both light and dark
  /// canvases without a shadow.
  static const Color defaultEdgeColor = Color(0xFFE3A400);

  /// Default outline width. Thinner than `SketchStyle`'s 2px: the edge is
  /// definition, not a drawn line, and at 2px it competed with the text.
  static const double defaultStrokeWidth = 1.5;

  /// Size a note takes when the gesture that created it didn't say — a press
  /// with no real drag — and the floor a drag-created one is grown to.
  ///
  /// There was no default before: the sticky tool made a note exactly the
  /// size of the drag rect, and a plain click produced a 0×0 rect that the
  /// commit path then discarded, so clicking with the sticky tool did
  /// nothing at all. Sized for two lines of [defaultFontSize] text inside
  /// [StickyBubbleGeometry]'s insets and tail band; a note that needs more
  /// grows on commit — see [fittedToText].
  static const Size defaultSize = Size(180, 72);

  /// Label size. Was 20, against 16 for every other element's text; that
  /// extra 25% is most of what made notes feel oversized, because a note has
  /// to be dragged big enough to fit its own label.
  static const double defaultFontSize = 16.0;

  /// Body rounding. A chat bubble is round; the old 4px read as a rectangle
  /// with softened corners.
  static const double defaultCornerRadius = 12.0;

  /// Style a note gets when its creator doesn't supply one. Stroke is the
  /// outline (see [defaultEdgeColor]), fill is the paper; a sticky is always
  /// filled, which is what makes it a bubble rather than a box.
  static const SketchStyle defaultStyle = SketchStyle(
    strokeColor: defaultEdgeColor,
    fillColor: defaultColor,
    fillStyle: FillStyle.solid,
    strokeWidth: defaultStrokeWidth,
  );

  /// Glyph colour used for dark notes, matching `SketchStyle`'s default ink.
  static const Color _darkInk = Color(0xFF1E1E1E);

  /// Glyph colour used for dark-papered notes.
  static const Color _lightInk = Color(0xFFF8F8F8);

  final double cornerRadius;

  /// Whether the note is showing as its badge instead of its bubble.
  ///
  /// Only the presentation changes: [rect] keeps the expanded geometry
  /// underneath, so expanding restores the size and position the user had
  /// rather than a default. [bounds] is what moves — see below.
  final bool collapsed;

  /// The box this note actually occupies on the canvas.
  ///
  /// Overridden because a collapsed note draws as a small badge, and bounds
  /// that disagree with what is drawn desynchronise selection rectangles,
  /// hit-testing, marquee selection, viewport culling and PNG export all at
  /// once — the same failure `SketchText.bounds` shipped when it guessed a
  /// width the painter never used.
  @override
  Rect get unrotatedBounds =>
      StickyBubbleGeometry.boundsOf(rect, collapsed: collapsed);

  /// Measured label sizes, one per note instance — see [labelSize].
  static final Expando<Size> _labelSizes = Expando<Size>(
    'SketchSticky.labelSize',
  );

  /// Colour this note's glyphs take — its label, and its badge's mark.
  ///
  /// Derived from the paper's luminance, not read from the style. On a
  /// sticky, [SketchStyle.strokeColor] is the bubble's *outline*, and glyphs
  /// drawn in the outline colour are either invisible (files saved before
  /// the outline existed have stroke == fill) or merely muddy (the default
  /// edge is a darker shade of the paper). A messenger never asks which
  /// colour the text in a bubble should be; it is whichever reads against
  /// the bubble — and that stays true when the user repaints the paper from
  /// the palette. A note with no fill at all is just an outline, and its
  /// text takes that outline's colour like any other shape's label.
  Color get inkColor {
    final paper = style.fillColor;
    if (paper == null || style.fillStyle == FillStyle.none) {
      return style.strokeColor;
    }
    return paper.computeLuminance() > 0.5 ? _darkInk : _lightInk;
  }

  /// The rect a note dragged out as [drawn] actually gets.
  ///
  /// A note is a text container, not a free-form shape: below the size its
  /// own label needs it is unusable, so each axis is floored at
  /// [defaultSize]. That is also what makes a plain click work — a 0×0 drag
  /// rect becomes a default-sized note at the press point instead of being
  /// discarded, which is what used to happen.
  ///
  /// Shared by the commit path and the drag preview so the note that lands
  /// is the note that was shown.
  static Rect rectFor(Rect drawn) => Rect.fromLTWH(
    drawn.left,
    drawn.top,
    math.max(drawn.width, defaultSize.width),
    math.max(drawn.height, defaultSize.height),
  );

  /// Where this note's label is laid out and how big it comes out, through
  /// the one layout the painter also draws with.
  ///
  /// Measured once per instance: the note is immutable, so the answer can
  /// never change under it, and [TextMetrics.measure]'s global cache is
  /// only the *first* measurement's source. Going through that cache on
  /// every read keyed the lookup on the whole label string, and once a
  /// board held more distinct strings than the cache could hold, every
  /// read was a full text layout.
  Size get labelSize {
    final label = text;
    if (label == null) return Size.zero;
    return _labelSizes[this] ??= TextMetrics.measure(
      text: label,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: bold ? FontWeight.w700 : null,
      maxWidth: StickyBubbleGeometry.textBoxOf(rect).width,
    );
  }

  /// This note grown, if need be, until its text fits — the way a messenger
  /// bubble takes the height of its message rather than clipping it.
  ///
  /// Grows only, never shrinks: a user who has deliberately made a note
  /// taller than its text keeps that, and a note whose text is shortened
  /// stays where it was rather than snapping about under the cursor. Width
  /// is left alone too; the text wraps to it.
  ///
  /// A note narrower than one em is skipped — wrapping a label one glyph
  /// per line into a 10px-wide sliver would grow it into a tower, which is
  /// worse than the clipping it would otherwise get.
  SketchSticky fittedToText() {
    if (text == null || collapsed) return this;
    if (StickyBubbleGeometry.textBoxOf(rect).width < fontSize) return this;
    final needed = StickyBubbleGeometry.heightFor(labelSize.height);
    if (needed <= rect.height) return this;
    return copyWith(
      rect: Rect.fromLTWH(rect.left, rect.top, rect.width, needed),
    );
  }

  SketchSticky copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    double? cornerRadius,
    Object? text = _unset,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    Object? groupId = _unset,
    bool? collapsed,
  }) {
    return SketchSticky(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  @override
  SketchSticky copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchSticky translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchSticky withId(String id) => copyWith(id: id);

  @override
  SketchSticky withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchSticky.create({
    String? id,
    required Rect rect,
    SketchStyle? style,
    String? text,
    double fontSize = defaultFontSize,
    double cornerRadius = defaultCornerRadius,
    bool collapsed = false,
  }) {
    return SketchSticky(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style ?? defaultStyle),
      rect: rect,
      text: text,
      fontSize: fontSize,
      cornerRadius: cornerRadius,
      collapsed: collapsed,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sticky',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'angle': angle,
    'cornerRadius': cornerRadius,
    if (text != null) 'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (groupId != null) 'groupId': groupId,
    // Written only when set, and defaulted on read, which is what keeps
    // this a schema-version-1 payload in both directions: a scene with no
    // collapsed notes serialises byte-for-byte as it did before the field
    // existed, and a scene saved by an older build still loads here.
    if (collapsed) 'collapsed': true,
  };

  factory SketchSticky.fromJson(Map<String, dynamic> json) {
    return SketchSticky(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: _angleFromJson(json),
      cornerRadius: _cornerRadiusFromJson(json, fallback: defaultCornerRadius),
      text: json['text'] as String?,
      fontSize: _fontSizeFromJson(json, fallback: defaultFontSize),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      groupId: json['groupId'] as String?,
      collapsed: json['collapsed'] as bool? ?? false,
    );
  }
}

// Sentinel for nullable copyWith parameters (allows distinguishing
// "no argument" from "explicit null").
const Object _unset = Object();

// ─── Linear shapes (line / arrow) ─────────────────────────────────────────

sealed class _SketchLinear extends SketchElement {
  const _SketchLinear({
    required super.id,
    required super.style,
    required this.start,
    required this.end,
    super.angle,
    super.groupId,
  });

  final Offset start;
  final Offset end;

  /// The box spanned by the two endpoints alone.
  Rect get _segmentBounds {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Rect get unrotatedBounds => _segmentBounds;
}

class SketchLine extends _SketchLinear {
  const SketchLine({
    required super.id,
    required super.style,
    required super.start,
    required super.end,
    super.angle,
    super.groupId,
  });

  SketchLine copyWith({
    String? id,
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchLine(
      id: id ?? this.id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchLine copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchLine translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

  @override
  SketchLine withId(String id) => copyWith(id: id);

  @override
  SketchLine withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchLine.create({
    String? id,
    required Offset start,
    required Offset end,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchLine(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      start: start,
      end: end,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'line',
    'id': id,
    'style': style.toJson(),
    'start': _offsetToJson(start),
    'end': _offsetToJson(end),
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchLine.fromJson(Map<String, dynamic> json) {
    return SketchLine(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

/// What an arrow end looks like. [arrow] is the classic filled triangle;
/// the rest are entity-relationship cardinality glyphs (crow's foot).
enum ArrowheadStyle { none, arrow, one, many, zeroOrOne, zeroOrMany, oneOrMany }

ArrowheadStyle _headFromJson(Object? raw, ArrowheadStyle fallback) {
  for (final style in ArrowheadStyle.values) {
    if (style.name == raw) return style;
  }
  return fallback;
}

class SketchArrow extends _SketchLinear {
  const SketchArrow({
    required super.id,
    required super.style,
    required super.start,
    required super.end,
    this.arrowSize = 10.0,
    super.angle,
    super.groupId,
    this.startBinding,
    this.endBinding,
    this.elbowed = false,
    this.startHead = ArrowheadStyle.none,
    this.endHead = ArrowheadStyle.arrow,
  });

  final double arrowSize;

  /// Shape this arrow's tail is attached to, or `null` when it floats.
  final SketchBinding? startBinding;

  /// Shape this arrow's head is attached to, or `null` when it floats.
  final SketchBinding? endBinding;

  /// Whether the shaft routes with right angles (see [ElbowRouter]) instead
  /// of running straight from [start] to [end].
  final bool elbowed;

  /// Glyph at [start]; none by default.
  final ArrowheadStyle startHead;

  /// Glyph at [end]; the classic triangle by default.
  final ArrowheadStyle endHead;

  /// The shaft as a polyline: two points when straight, the derived
  /// right-angle route when [elbowed].
  List<Offset> get points =>
      elbowed ? ElbowRouter.route(start, end) : [start, end];

  /// Half-angle of the head's wings, in radians — the `0.5` in
  /// `ArrowHead.path`, which is what the painter draws with.
  static const double _headHalfAngle = 0.5;

  /// Length of the head as painted: the larger of [arrowSize] and six
  /// stroke widths, so a thick arrow keeps its proportions. Mirrors
  /// `SketchPainter._drawArrowHead`; the two must agree or [bounds] lies.
  double get headLength => math.max(arrowSize, style.strokeWidth * 6.0);

  /// The shaft's box grown to take in the heads.
  ///
  /// A head is a glyph with its tip at the endpoint and two wings
  /// [headLength] back along the last segment, swung ±[_headHalfAngle] off
  /// it (every [ArrowheadStyle] glyph stays inside that envelope) — so on an
  /// axis-aligned arrow the wings stick out sideways by
  /// `headLength * sin(0.5)` on both sides of a box that is otherwise zero
  /// pixels tall. Elbowed arrows include every bend.
  @override
  Rect get unrotatedBounds {
    final pts = points;
    var box = _segmentBounds;
    for (final p in pts) {
      box = box.expandToInclude(Rect.fromPoints(p, p));
    }
    if (endHead != ArrowheadStyle.none) {
      box = _withWings(box, pts[pts.length - 2], pts.last);
    }
    if (startHead != ArrowheadStyle.none) {
      box = _withWings(box, pts[1], pts.first);
    }
    // Cardinality glyphs reach 1.3 head-lengths back and 0.4 to the side
    // (see `ArrowHead.pathFor`), beyond what the wing points cover.
    final glyph =
        (startHead != ArrowheadStyle.none &&
            startHead != ArrowheadStyle.arrow) ||
        (endHead != ArrowheadStyle.none && endHead != ArrowheadStyle.arrow);
    return glyph ? box.inflate(headLength * 0.65) : box;
  }

  /// [box] grown to hold the two wing tips of a head at [tip], whose shaft
  /// arrives from [from].
  Rect _withWings(Rect box, Offset from, Offset tip) {
    final shaft = tip - from;
    if (shaft == Offset.zero) return box;
    final direction = math.atan2(shaft.dy, shaft.dx);
    final size = headLength;
    for (final side in const <double>[-_headHalfAngle, _headHalfAngle]) {
      final wing = Offset(
        tip.dx - size * math.cos(direction + side),
        tip.dy - size * math.sin(direction + side),
      );
      box = box.expandToInclude(Rect.fromPoints(wing, wing));
    }
    return box;
  }

  SketchArrow copyWith({
    String? id,
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? arrowSize,
    double? angle,
    Object? groupId = _unset,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    bool? elbowed,
    ArrowheadStyle? startHead,
    ArrowheadStyle? endHead,
  }) {
    return SketchArrow(
      id: id ?? this.id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      startBinding: identical(startBinding, _unset)
          ? this.startBinding
          : startBinding as SketchBinding?,
      endBinding: identical(endBinding, _unset)
          ? this.endBinding
          : endBinding as SketchBinding?,
      elbowed: elbowed ?? this.elbowed,
      startHead: startHead ?? this.startHead,
      endHead: endHead ?? this.endHead,
    );
  }

  @override
  SketchArrow copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchArrow translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

  @override
  SketchArrow withId(String id) => copyWith(id: id);

  @override
  SketchArrow withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchArrow.create({
    String? id,
    required Offset start,
    required Offset end,
    SketchStyle style = const SketchStyle(),
    double arrowSize = 10.0,
    bool elbowed = false,
    ArrowheadStyle startHead = ArrowheadStyle.none,
    ArrowheadStyle endHead = ArrowheadStyle.arrow,
  }) {
    return SketchArrow(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      start: start,
      end: end,
      arrowSize: arrowSize,
      elbowed: elbowed,
      startHead: startHead,
      endHead: endHead,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'arrow',
    'id': id,
    'style': style.toJson(),
    'start': _offsetToJson(start),
    'end': _offsetToJson(end),
    'arrowSize': arrowSize,
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
    if (startBinding != null) 'startBinding': startBinding!.toJson(),
    if (endBinding != null) 'endBinding': endBinding!.toJson(),
    // Written only when non-default, so an old-style arrow serialises
    // exactly as it did before these fields existed.
    if (elbowed) 'elbowed': true,
    if (startHead != ArrowheadStyle.none) 'startHead': startHead.name,
    if (endHead != ArrowheadStyle.arrow) 'endHead': endHead.name,
  };

  factory SketchArrow.fromJson(Map<String, dynamic> json) {
    return SketchArrow(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      arrowSize: _clampedDouble(
        json['arrowSize'],
        min: 0.0,
        max: _maxArrowSize,
        fallback: 10.0,
      ),
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
      startBinding: _bindingFromJson(json['startBinding']),
      endBinding: _bindingFromJson(json['endBinding']),
      elbowed: json['elbowed'] as bool? ?? false,
      startHead: _headFromJson(json['startHead'], ArrowheadStyle.none),
      endHead: _headFromJson(json['endHead'], ArrowheadStyle.arrow),
    );
  }
}

/// Attachment of one arrow endpoint to another element.
///
/// Reserved: nothing binds arrows yet, and nothing reads these fields. It
/// ships in v1 anyway because the alternative is worse — a field that first
/// appears in a later release makes every file already saved by a v1 user
/// forward-incompatible and forces a schema bump to fix. Reserving it now
/// costs one class.
///
/// A value type rather than a bare element id for the same reason: [focus]
/// and [gap] are what the binding feature will need, and introducing them
/// later would be a second migration.
class SketchBinding {
  const SketchBinding({
    required this.elementId,
    this.focus = 0.0,
    this.gap = 0.0,
    this.attribute,
  });

  /// Element the endpoint is attached to.
  final String elementId;

  /// Where along the bound element the arrow aims, `-1..1`, with `0` for
  /// its centre.
  final double focus;

  /// Canvas-space distance the endpoint keeps from the bound element's edge.
  final double gap;

  /// Entity row (attribute name) the endpoint anchors to, for a bound
  /// [SketchEntity]; `null` anchors to the shape as a whole.
  final String? attribute;

  Map<String, dynamic> toJson() => {
    'elementId': elementId,
    'focus': focus,
    'gap': gap,
    if (attribute != null) 'attribute': attribute,
  };

  factory SketchBinding.fromJson(Map<String, dynamic> json) {
    return SketchBinding(
      elementId: json['elementId'] as String,
      focus: (json['focus'] as num?)?.toDouble() ?? 0.0,
      gap: (json['gap'] as num?)?.toDouble() ?? 0.0,
      attribute: json['attribute'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SketchBinding &&
        other.elementId == elementId &&
        other.focus == focus &&
        other.gap == gap &&
        other.attribute == attribute;
  }

  @override
  int get hashCode => Object.hash(elementId, focus, gap, attribute);
}

SketchBinding? _bindingFromJson(Object? raw) =>
    raw is Map ? SketchBinding.fromJson(raw.cast<String, dynamic>()) : null;

// ─── Freedraw ──────────────────────────────────────────────────────────────

class SketchFreedraw extends SketchElement {
  SketchFreedraw({
    required super.id,
    required super.style,
    required List<Offset> points,
    super.angle,
    super.groupId,
  }) : assert(points.isNotEmpty, 'freedraw must contain at least one point'),
       points = List<Offset>.unmodifiable(points);

  final List<Offset> points;

  @override
  Rect get unrotatedBounds {
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = minX, maxY = minY;
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  SketchFreedraw copyWith({
    String? id,
    List<Offset>? points,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchFreedraw(
      id: id ?? this.id,
      style: style ?? this.style,
      points: points ?? this.points,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchFreedraw copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchFreedraw withId(String id) => copyWith(id: id);

  @override
  SketchFreedraw withGroupId(String? groupId) => copyWith(groupId: groupId);

  @override
  SketchFreedraw translate(Offset delta) {
    final shifted = <Offset>[for (final p in points) p + delta];
    return copyWith(points: shifted);
  }

  factory SketchFreedraw.create({
    String? id,
    required List<Offset> points,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchFreedraw(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      points: points,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'freedraw',
    'id': id,
    'style': style.toJson(),
    'points': [for (final p in points) _offsetToJson(p)],
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchFreedraw.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List<dynamic>;
    if (raw.isEmpty) {
      throw const FormatException('freedraw must contain at least one point');
    }
    return SketchFreedraw(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      // Every point goes through `_offsetFromJson`, which is where a
      // non-finite coordinate is refused — one `1e999` in a 5 000-point
      // stroke drops the stroke, not the file.
      points: [for (final p in raw) _offsetFromJson(p as Map<String, dynamic>)],
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

// ─── Text ──────────────────────────────────────────────────────────────────

class SketchText extends SketchElement {
  const SketchText({
    required super.id,
    required super.style,
    required this.position,
    required this.text,
    this.fontSize = 16.0,
    this.fontFamily,
    this.bold = false,
    this.align = TextAlign.start,
    super.angle,
    super.groupId,
  });

  final Offset position;
  final String text;
  final double fontSize;
  final String? fontFamily;
  final bool bold;

  /// Horizontal alignment of the lines within the text's own box; only
  /// visible on multi-line text, since the box is as wide as its widest line.
  final TextAlign align;

  /// Measured boxes, one per text instance — see [unrotatedBounds].
  ///
  /// An [Expando] rather than a `late final` field because the constructor
  /// is `const`; it is keyed on identity and collected with the element, so
  /// there is no eviction policy to fall off.
  static final Expando<Rect> _measuredBounds = Expando<Rect>(
    'SketchText.bounds',
  );

  /// Measured through the same layout the painter draws with, so the box
  /// hit-testing and culling see is exactly the box the user sees. An
  /// approximation here silently desynchronises the two.
  ///
  /// Measured once per instance. The element is immutable, so nothing the
  /// measurement depends on can change; and going through
  /// [TextMetrics.measure]'s global cache on every read meant building a
  /// key from the whole string each time, then — on a board with more
  /// distinct strings than that cache holds — a full text layout per read,
  /// per element, per frame. The global cache is still what serves the
  /// first measurement, so a re-typed label is not laid out twice.
  @override
  Rect get unrotatedBounds => _measuredBounds[this] ??= _measure();

  Rect _measure() {
    final size = TextMetrics.measure(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: bold ? FontWeight.w700 : null,
      textAlign: align,
    );
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  SketchText copyWith({
    String? id,
    Offset? position,
    String? text,
    double? fontSize,
    Object? fontFamily = _unset,
    bool? bold,
    TextAlign? align,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchText(
      id: id ?? this.id,
      style: style ?? this.style,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      // Sentinel, not `??`: `null` is a real value here — the platform
      // default face — and has to be settable back once a family was chosen.
      fontFamily: identical(fontFamily, _unset)
          ? this.fontFamily
          : fontFamily as String?,
      bold: bold ?? this.bold,
      align: align ?? this.align,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchText copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchText translate(Offset delta) => copyWith(position: position + delta);

  @override
  SketchText withId(String id) => copyWith(id: id);

  @override
  SketchText withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchText.create({
    String? id,
    required Offset position,
    required String text,
    double fontSize = 16.0,
    String? fontFamily,
    bool bold = false,
    TextAlign align = TextAlign.start,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchText(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      position: position,
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      bold: bold,
      align: align,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'text',
    'id': id,
    'style': style.toJson(),
    'position': _offsetToJson(position),
    'text': text,
    'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (bold) 'bold': true,
    if (align != TextAlign.start) 'align': align.name,
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchText.fromJson(Map<String, dynamic> json) {
    return SketchText(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      position: _offsetFromJson(json['position'] as Map<String, dynamic>),
      text: json['text'] as String,
      fontSize: _fontSizeFromJson(json, fallback: 16.0),
      fontFamily: json['fontFamily'] as String?,
      bold: json['bold'] as bool? ?? false,
      align: _alignFromJson(json['align']),
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

// ─── Frame / icon / image / entity ─────────────────────────────────────────
//
// These extend [SketchElement] directly rather than `_SketchBoundedShape`:
// that base exists for shapes carrying a centred text label (`text`,
// `fontSize`, font family), which none of these has — a frame's name sits
// above its border, an icon and an image have no text at all, and an
// entity lays out its own header and rows.

/// A labelled region that visually groups what lies inside it.
///
/// Membership is computed by containment (`FrameMembership`), never stored.
class SketchFrame extends SketchElement {
  const SketchFrame({
    required super.id,
    required super.style,
    required this.rect,
    this.name = '',
    super.angle,
    super.groupId,
  });

  final Rect rect;
  final String name;

  @override
  Rect get unrotatedBounds => rect;

  SketchFrame copyWith({
    String? id,
    Rect? rect,
    String? name,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchFrame(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      name: name ?? this.name,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchFrame copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchFrame translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchFrame withId(String id) => copyWith(id: id);

  @override
  SketchFrame withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchFrame.create({
    String? id,
    required Rect rect,
    String name = '',
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchFrame(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      name: name,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'frame',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'angle': angle,
    if (name.isNotEmpty) 'name': name,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchFrame.fromJson(Map<String, dynamic> json) {
    return SketchFrame(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      name: json['name'] as String? ?? '',
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

/// A named glyph from `iconCatalog`, drawn at the size of its [rect].
class SketchIcon extends SketchElement {
  const SketchIcon({
    required super.id,
    required super.style,
    required this.rect,
    required this.name,
    super.angle,
    super.groupId,
  });

  final Rect rect;

  /// Key into `iconCatalog`; an unknown name renders as a help glyph.
  final String name;

  @override
  Rect get unrotatedBounds => rect;

  SketchIcon copyWith({
    String? id,
    Rect? rect,
    String? name,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchIcon(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      name: name ?? this.name,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchIcon copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchIcon translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchIcon withId(String id) => copyWith(id: id);

  @override
  SketchIcon withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchIcon.create({
    String? id,
    required Rect rect,
    required String name,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchIcon(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      name: name,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'icon',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'name': name,
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchIcon.fromJson(Map<String, dynamic> json) {
    return SketchIcon(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      name: json['name'] as String,
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

/// Largest single embedded image, and the most image bytes one scene may
/// carry. Enforced when an image is parsed, so a hostile or runaway file
/// cannot balloon memory or the autosave payload.
const int maxImageBytes = 4 * 1024 * 1024;
const int maxSceneImageBytes = 16 * 1024 * 1024;

/// MIME types an embedded image may declare.
const Set<String> imageMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
};

/// A raster image stored inline (base64 under `data`) so a scene file stays
/// self-contained.
class SketchImage extends SketchElement {
  const SketchImage({
    required super.id,
    required super.style,
    required this.rect,
    required this.mimeType,
    required this.bytes,
    super.angle,
    super.groupId,
  });

  final Rect rect;
  final String mimeType;
  final Uint8List bytes;

  @override
  Rect get unrotatedBounds => rect;

  SketchImage copyWith({
    String? id,
    Rect? rect,
    String? mimeType,
    Uint8List? bytes,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchImage(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? this.bytes,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchImage copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchImage translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchImage withId(String id) => copyWith(id: id);

  @override
  SketchImage withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchImage.create({
    String? id,
    required Rect rect,
    required String mimeType,
    required Uint8List bytes,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchImage(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'mimeType': mimeType,
    'data': base64Encode(bytes),
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchImage.fromJson(Map<String, dynamic> json) {
    final mime = json['mimeType'] as String;
    if (!imageMimeTypes.contains(mime)) {
      throw FormatException('unsupported image type: $mime');
    }
    final data = json['data'] as String;
    // Cheap pre-check before decoding: base64 inflates by 4/3.
    if (data.length > maxImageBytes * 4 ~/ 3 + 4) {
      throw const FormatException('image larger than the 4 MiB limit');
    }
    final bytes = base64Decode(data);
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FormatException('image is empty or over the 4 MiB limit');
    }
    return SketchImage(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      mimeType: mime,
      bytes: bytes,
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

/// One row of a [SketchEntity].
class EntityAttribute {
  const EntityAttribute({
    required this.name,
    this.type = '',
    this.primaryKey = false,
    this.foreignKey = false,
  });

  final String name;
  final String type;
  final bool primaryKey;
  final bool foreignKey;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (type.isNotEmpty) 'type': type,
    if (primaryKey) 'pk': true,
    if (foreignKey) 'fk': true,
  };

  factory EntityAttribute.fromJson(Map<String, dynamic> json) {
    return EntityAttribute(
      name: json['name'] as String,
      type: json['type'] as String? ?? '',
      primaryKey: json['pk'] as bool? ?? false,
      foreignKey: json['fk'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntityAttribute &&
      other.name == name &&
      other.type == type &&
      other.primaryKey == primaryKey &&
      other.foreignKey == foreignKey;

  @override
  int get hashCode => Object.hash(name, type, primaryKey, foreignKey);
}

/// An ER-diagram table: a header with the entity's [name] and one row per
/// attribute. Height is derived from the rows ([fittedToAttributes]); width
/// is the user's.
class SketchEntity extends SketchElement {
  SketchEntity({
    required super.id,
    required super.style,
    required this.rect,
    this.name = '',
    List<EntityAttribute> attributes = const [],
    this.fontSize = defaultFontSize,
    super.angle,
    super.groupId,
  }) : attributes = List<EntityAttribute>.unmodifiable(attributes);

  static const double defaultFontSize = 14.0;

  /// Row pitch as a multiple of [fontSize]; the header takes one row too.
  static const double rowFactor = 1.7;

  final Rect rect;
  final String name;
  final List<EntityAttribute> attributes;
  final double fontSize;

  double get rowHeight => fontSize * rowFactor;
  double get headerHeight => rowHeight;

  /// Height the header plus every row needs.
  double get fittedHeight => headerHeight + attributes.length * rowHeight;

  /// Canvas y of the vertical centre of the row named [attribute], or
  /// `null` when there is no such row. Arrows bound to an attribute anchor
  /// here.
  double? rowCenterY(String attribute) {
    final i = attributes.indexWhere((a) => a.name == attribute);
    if (i < 0) return null;
    return rect.top + headerHeight + (i + 0.5) * rowHeight;
  }

  /// This entity with its height set to exactly what its rows need (cf.
  /// `SketchSticky.fittedToText`, but it shrinks too: the height is
  /// derived, not user-chosen).
  SketchEntity fittedToAttributes() {
    final h = fittedHeight;
    if (h == rect.height) return this;
    return copyWith(rect: Rect.fromLTWH(rect.left, rect.top, rect.width, h));
  }

  @override
  Rect get unrotatedBounds => rect;

  SketchEntity copyWith({
    String? id,
    Rect? rect,
    String? name,
    List<EntityAttribute>? attributes,
    double? fontSize,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchEntity(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      name: name ?? this.name,
      attributes: attributes ?? this.attributes,
      fontSize: fontSize ?? this.fontSize,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchEntity copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchEntity translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchEntity withId(String id) => copyWith(id: id);

  @override
  SketchEntity withGroupId(String? groupId) => copyWith(groupId: groupId);

  /// Entity at [rect]'s top-left and width, with the height its rows need.
  factory SketchEntity.create({
    String? id,
    required Rect rect,
    String name = '',
    List<EntityAttribute> attributes = const [],
    double fontSize = defaultFontSize,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchEntity(
      id: id ?? IdGenerator.generate('sketch'),
      style: _seeded(style),
      rect: rect,
      name: name,
      attributes: attributes,
      fontSize: fontSize,
    ).fittedToAttributes();
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'entity',
    'id': id,
    'style': style.toJson(),
    'rect': _rectToJson(rect),
    'name': name,
    'attributes': [for (final a in attributes) a.toJson()],
    'fontSize': fontSize,
    'angle': angle,
    if (groupId != null) 'groupId': groupId,
  };

  factory SketchEntity.fromJson(Map<String, dynamic> json) {
    return SketchEntity(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      name: json['name'] as String? ?? '',
      attributes: [
        for (final a in json['attributes'] as List<dynamic>? ?? const [])
          EntityAttribute.fromJson((a as Map).cast<String, dynamic>()),
      ],
      fontSize: _fontSizeFromJson(json, fallback: defaultFontSize),
      angle: _angleFromJson(json),
      groupId: json['groupId'] as String?,
    );
  }
}

// ─── Creation helpers ──────────────────────────────────────────────────────

final math.Random _seedSource = math.Random();

/// A fresh [SketchStyle.seed] for a newly created element.
///
/// Drawn from `1..0x7FFFFFFE`, open at both ends of the Park–Miller range
/// the rough generator runs on: a state of `0` or of the modulus itself
/// collapses its stream to a constant, i.e. a perfectly straight "sketch".
int _freshSeed() => 1 + _seedSource.nextInt(0x7FFFFFFE);

/// [style] with a seed of its own, unless the caller chose one.
///
/// Every `create` factory goes through this so no two shapes wobble
/// identically — the default [SketchStyle] carries [SketchStyle.defaultSeed],
/// and before this nothing ever replaced it, so every same-sized shape on a
/// board had the very same jitter. `fromJson` does not: a file's seeds are
/// the file's, and a scene has to render the same on every open.
SketchStyle _seeded(SketchStyle style) => style.seed == SketchStyle.defaultSeed
    ? style.copyWith(seed: _freshSeed())
    : style;

// ─── Geometry helpers ──────────────────────────────────────────────────────

/// Axis-aligned box of [rect] rotated by [angle] radians about its centre.
///
/// The centre is the pivot, so the result shares it with [rect] — which is
/// what lets [SketchElement.bounds] and the painter agree on where to
/// rotate without either reading the other.
Rect _rotatedAabb(Rect rect, double angle) {
  final c = rect.center;
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final corner in <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ]) {
    final dx = corner.dx - c.dx;
    final dy = corner.dy - c.dy;
    final x = c.dx + dx * cos - dy * sin;
    final y = c.dy + dx * sin + dy * cos;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

// ─── JSON helpers ──────────────────────────────────────────────────────────

/// Widest label any element will lay out, in logical pixels. Matches the
/// MCP layer's cap; past it a single glyph is a canvas-sized paragraph.
const double _maxFontSize = 512.0;

/// Longest arrow head a file may ask for. Generous — the UI maxes out at a
/// fraction of this — but finite, so a head can't be wider than the board.
const double _maxArrowSize = 512.0;

Map<String, double> _offsetToJson(Offset o) => {'dx': o.dx, 'dy': o.dy};

Offset _offsetFromJson(Map<String, dynamic> json) =>
    Offset(_finite(json['dx'], 'dx'), _finite(json['dy'], 'dy'));

Map<String, double> _rectToJson(Rect r) => {
  'l': r.left,
  't': r.top,
  'w': r.width,
  'h': r.height,
};

Rect _rectFromJson(Map<String, dynamic> json) => Rect.fromLTWH(
  _finite(json['l'], 'l'),
  _finite(json['t'], 't'),
  _finite(json['w'], 'w'),
  _finite(json['h'], 'h'),
);

/// A required geometry coordinate: present, numeric and finite.
///
/// `jsonDecode('1e999')` is `double.infinity`, and an infinite edge makes an
/// element that is invisible, unhittable — and unserialisable, so from then
/// on every autosave of the whole project throws. Refused here as a
/// [FormatException], which `SketchSerializer.load` catches per element:
/// the bad shape is dropped and reported, the file survives.
double _finite(Object? raw, String key) {
  if (raw is! num) {
    throw FormatException('"$key" must be a number, got: $raw');
  }
  final value = raw.toDouble();
  if (!value.isFinite) {
    throw FormatException('"$key" must be a finite number, got: $raw');
  }
  return value;
}

/// An optional numeric field clamped into [min]..[max].
///
/// Missing, or present but not finite, yields [fallback]; a wrong type is
/// still an error, like every other field. Clamped rather than refused
/// because these are *style* numbers — a font size of `1e6` is a file worth
/// rescuing, where a coordinate of `1e999` is not.
double _clampedDouble(
  Object? raw, {
  required double min,
  required double max,
  required double fallback,
}) {
  if (raw == null) return fallback;
  if (raw is! num) {
    throw FormatException('expected a number, got: $raw');
  }
  final value = raw.toDouble();
  if (!value.isFinite) return fallback;
  return value.clamp(min, max);
}

double _fontSizeFromJson(
  Map<String, dynamic> json, {
  required double fallback,
}) => _clampedDouble(
  json['fontSize'],
  min: 1.0,
  max: _maxFontSize,
  fallback: fallback,
);

/// Only left/center/right are valid alignments; anything else is the default.
TextAlign _alignFromJson(Object? raw) => switch (raw) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  'left' => TextAlign.left,
  _ => TextAlign.start,
};

double _cornerRadiusFromJson(
  Map<String, dynamic> json, {
  required double fallback,
}) => _clampedDouble(
  json['cornerRadius'],
  min: 0.0,
  max: double.infinity,
  fallback: fallback,
);

/// Rotation is a coordinate of sorts: a NaN angle makes every rotated
/// corner NaN, so it gets the fallback rather than poisoning [bounds].
double _angleFromJson(Map<String, dynamic> json) => _clampedDouble(
  json['angle'],
  min: double.negativeInfinity,
  max: double.infinity,
  fallback: 0.0,
);
