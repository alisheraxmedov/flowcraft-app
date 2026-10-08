import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// One drawable element of an [FcIcon], in the icon's viewBox units.
///
/// Mirrors the SVG elements the Glass Canvas mockups use. [strokeWidth]
/// overrides the icon's width for this element only (the fill-style previews
/// mix 1.75 / 1.2 / 1.1); [fillOpacity] fills the shape with the glyph colour
/// at that opacity; [dash] is an SVG `stroke-dasharray`.
sealed class FcShape {
  const FcShape({this.strokeWidth, this.fillOpacity, this.dash});

  final double? strokeWidth;
  final double? fillOpacity;
  final List<double>? dash;

  void addTo(ui.Path path);
}

/// SVG `<path d>`.
class FcPath extends FcShape {
  const FcPath(this.d, {super.strokeWidth, super.fillOpacity, super.dash});

  final String d;

  @override
  void addTo(ui.Path path) => writeSvgPathDataToPath(d, _UiPathProxy(path));
}

/// SVG `<rect>`; a non-zero [rx] becomes a rounded rect.
class FcRect extends FcShape {
  const FcRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.rx = 0,
    super.strokeWidth,
    super.fillOpacity,
    super.dash,
  });

  final double x, y, width, height, rx;

  @override
  void addTo(ui.Path path) {
    final r = Rect.fromLTWH(x, y, width, height);
    rx == 0
        ? path.addRect(r)
        : path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(rx)));
  }
}

/// SVG `<circle>`.
class FcCircle extends FcShape {
  const FcCircle(
    this.cx,
    this.cy,
    this.r, {
    super.strokeWidth,
    super.fillOpacity,
    super.dash,
  });

  final double cx, cy, r;

  @override
  void addTo(ui.Path path) =>
      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

/// SVG `<line>`.
class FcLine extends FcShape {
  const FcLine(
    this.x1,
    this.y1,
    this.x2,
    this.y2, {
    super.strokeWidth,
    super.fillOpacity,
    super.dash,
  });

  final double x1, y1, x2, y2;

  @override
  void addTo(ui.Path path) => path
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);
}

/// SVG `<polyline>`; [points] is the flat `x y x y ...` list.
// ponytail: open polylines only (no <polygon>/<ellipse> — no icon uses them),
// add a closed flag if a future icon needs one.
class FcPolyline extends FcShape {
  const FcPolyline(
    this.points, {
    super.strokeWidth,
    super.fillOpacity,
    super.dash,
  });

  final List<double> points;

  @override
  void addTo(ui.Path path) {
    path.moveTo(points[0], points[1]);
    for (var i = 2; i < points.length; i += 2) {
      path.lineTo(points[i], points[i + 1]);
    }
  }
}

/// A stroke-style icon: `fill="none"`, round caps and joins, drawn in a
/// [width] x [height] viewBox. All Lucide icons are 24x24 at 1.75; the stroke
/// and fill preview glyphs carry their own box.
class FcIcon {
  const FcIcon(
    this.name,
    this.shapes, {
    this.width = 24,
    this.height = 24,
    this.strokeWidth = 1.75,
    this.color,
  });

  final String name;
  final List<FcShape> shapes;
  final double width, height, strokeWidth;

  /// Fixed colour for the few glyphs that hard-code one in the mockup
  /// (the red "no stroke" slash). An explicit `FcIconGlyph.color` still wins.
  final Color? color;
}

/// Adapts `dart:ui` [ui.Path] to path_parsing's [PathProxy].
class _UiPathProxy implements PathProxy {
  _UiPathProxy(this._p);
  final ui.Path _p;

  @override
  void moveTo(double x, double y) => _p.moveTo(x, y);
  @override
  void lineTo(double x, double y) => _p.lineTo(x, y);
  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => _p.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => _p.close();
}

/// Every chrome icon, rendered 1:1 from the Glass Canvas mockups
/// (`C-Board` / `C-Parts`) or, where the mockups show none, from the official
/// Lucide set in the same style. Lucide is ISC: see `assets/icons/Lucide-LICENSE.txt`.
abstract final class FcIcons {
  // ---- Extracted from the mockups (41 distinct SVGs) ----

  static const FcIcon logoMark = FcIcon('logoMark', [
    FcRect(2, 2, 20, 20, rx: 6, fillOpacity: 0.12),
    FcPath('M6.5 15.5 C 9 7, 13 17, 17.5 8.5'),
  ]);

  static const FcIcon panelLeft = FcIcon('panelLeft', [
    FcRect(3, 3, 18, 18, rx: 2),
    FcPath('M9 3v18'),
  ]);

  static const FcIcon mousePointer2 = FcIcon('mousePointer2', [
    FcPath(
      'M4.037 4.688a.495.495 0 0 1 .651-.651l16 6.5a.5.5 0 0 1-.063.947l-6.124 1.58a2 2 0 0 0-1.438 1.435l-1.579 6.126a.5.5 0 0 1-.947.063z',
    ),
  ]);

  static const FcIcon hand = FcIcon('hand', [
    FcPath('M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2'),
    FcPath('M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2'),
    FcPath('M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8'),
    FcPath(
      'M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 3.14-2.5L7 15',
    ),
  ]);

  static const FcIcon square = FcIcon('square', [FcRect(3, 3, 18, 18, rx: 2)]);

  static const FcIcon circle = FcIcon('circle', [FcCircle(12, 12, 10)]);

  static const FcIcon diamond = FcIcon('diamond', [
    FcPath(
      'M2.7 10.3a2.41 2.41 0 0 0 0 3.41l7.59 7.59a2.41 2.41 0 0 0 3.41 0l7.59-7.59a2.41 2.41 0 0 0 0-3.41l-7.59-7.59a2.41 2.41 0 0 0-3.41 0Z',
    ),
  ]);

  static const FcIcon triangle = FcIcon('triangle', [
    FcPath(
      'M13.73 4a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z',
    ),
  ]);

  static const FcIcon stickyNote = FcIcon('stickyNote', [
    FcPath('M16 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8Z'),
    FcPath('M15 3v4a2 2 0 0 0 2 2h4'),
  ]);

  static const FcIcon lineDiagonal = FcIcon('lineDiagonal', [
    FcPath('M5 19 19 5'),
  ]);

  static const FcIcon arrowUpRight = FcIcon('arrowUpRight', [
    FcPath('M7 7h10v10'),
    FcPath('M7 17 17 7'),
  ]);

  static const FcIcon pencil = FcIcon('pencil', [
    FcPath('M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z'),
    FcPath('m15 5 4 4'),
  ]);

  static const FcIcon type = FcIcon('type', [
    FcPolyline([4, 7, 4, 4, 20, 4, 20, 7]),
    FcLine(9, 20, 15, 20),
    FcLine(12, 4, 12, 20),
  ]);

  static const FcIcon eraser = FcIcon('eraser', [
    FcPath(
      'm7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21',
    ),
    FcPath('M22 21H7'),
    FcPath('m5 11 9 9'),
  ]);

  static const FcIcon chevronDown = FcIcon('chevronDown', [
    FcPath('m6 9 6 6 6-6'),
  ]);

  static const FcIcon upload = FcIcon('upload', [
    FcPath('M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'),
    FcPolyline([17, 8, 12, 3, 7, 8]),
    FcLine(12, 3, 12, 15),
  ]);

  static const FcIcon strokeNone = FcIcon(
    'strokeNone',
    [FcPath('M5 17 17 5')],
    width: 22,
    height: 22,
    color: Color(0xFFE03131),
  );

  static const FcIcon strokeSolid = FcIcon(
    'strokeSolid',
    [FcPath('M2 2h24')],
    width: 28,
    height: 4,
  );

  static const FcIcon strokeDashed = FcIcon(
    'strokeDashed',
    [
      FcPath('M2 2h24', dash: [5, 4]),
    ],
    width: 28,
    height: 4,
  );

  static const FcIcon strokeDotted = FcIcon(
    'strokeDotted',
    [
      FcPath('M2 2h24', dash: [0.1, 4.5]),
    ],
    width: 28,
    height: 4,
  );

  static const FcIcon fillNone = FcIcon(
    'fillNone',
    [FcRect(1, 1, 20, 12, rx: 2.5)],
    width: 22,
    height: 14,
  );

  static const FcIcon fillSolid = FcIcon(
    'fillSolid',
    [FcRect(1, 1, 20, 12, rx: 2.5, fillOpacity: .35)],
    width: 22,
    height: 14,
  );

  static const FcIcon fillHachure = FcIcon(
    'fillHachure',
    [
      FcRect(1, 1, 20, 12, rx: 2.5),
      FcPath('M6 12 11 2M11 12 16 2M16 12l3-5.5M3 8l2.5-5', strokeWidth: 1.2),
    ],
    width: 22,
    height: 14,
  );

  static const FcIcon fillCrossHatch = FcIcon(
    'fillCrossHatch',
    [
      FcRect(1, 1, 20, 12, rx: 2.5),
      FcPath(
        'M6 12 11 2M11 12 16 2M16 12l3-5.5M3 8l2.5-5M6 2l5 10M11 2l5 10M16 2l3 5.5M3 6l2.5 5',
        strokeWidth: 1.1,
      ),
    ],
    width: 22,
    height: 14,
  );

  static const FcIcon code = FcIcon('code', [
    FcPolyline([16, 18, 22, 12, 16, 6]),
    FcPolyline([8, 6, 2, 12, 8, 18]),
  ]);

  static const FcIcon undo2 = FcIcon('undo2', [
    FcPath('M9 14 4 9l5-5'),
    FcPath('M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11'),
  ]);

  static const FcIcon redo2 = FcIcon('redo2', [
    FcPath('m15 14 5-5-5-5'),
    FcPath('M20 9H9.5A5.5 5.5 0 0 0 4 14.5A5.5 5.5 0 0 0 9.5 20H13'),
  ]);

  static const FcIcon grid3x3 = FcIcon('grid3x3', [
    FcRect(3, 3, 18, 18, rx: 2),
    FcPath('M3 9h18'),
    FcPath('M3 15h18'),
    FcPath('M9 3v18'),
    FcPath('M15 3v18'),
  ]);

  static const FcIcon moon = FcIcon('moon', [
    FcPath('M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z'),
  ]);

  static const FcIcon plus = FcIcon('plus', [
    FcPath('M5 12h14'),
    FcPath('M12 5v14'),
  ]);

  static const FcIcon ellipsis = FcIcon('ellipsis', [
    FcCircle(12, 12, 1),
    FcCircle(19, 12, 1),
    FcCircle(5, 12, 1),
  ]);

  static const FcIcon trash = FcIcon('trash', [
    FcPath('M3 6h18'),
    FcPath('M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6'),
    FcPath('M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2'),
  ]);

  static const FcIcon image = FcIcon('image', [
    FcRect(3, 3, 18, 18, rx: 2),
    FcCircle(9, 9, 2),
    FcPath('m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21'),
  ]);

  static const FcIcon fileJson = FcIcon('fileJson', [
    FcPath('M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'),
    FcPath('M14 2v6h6'),
    FcPath(
      'M10 12a1 1 0 0 0-1 1v1a1 1 0 0 1-1 1 1 1 0 0 1 1 1v1a1 1 0 0 0 1 1',
    ),
    FcPath(
      'M14 18a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1 1 1 0 0 1-1-1v-1a1 1 0 0 0-1-1',
    ),
  ]);

  static const FcIcon copy = FcIcon('copy', [
    FcRect(8, 8, 14, 14, rx: 2),
    FcPath('M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2'),
  ]);

  static const FcIcon download = FcIcon('download', [
    FcPath('M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'),
    FcPolyline([7, 10, 12, 15, 17, 10]),
    FcLine(12, 15, 12, 3),
  ]);

  static const FcIcon clipboard = FcIcon('clipboard', [
    FcRect(8, 2, 8, 4, rx: 1),
    FcPath(
      'M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2',
    ),
  ]);

  static const FcIcon link = FcIcon('link', [
    FcPath('M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'),
    FcPath('M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'),
  ]);

  static const FcIcon slidersHorizontal = FcIcon('slidersHorizontal', [
    FcLine(21, 4, 14, 4),
    FcLine(10, 4, 3, 4),
    FcLine(21, 12, 12, 12),
    FcLine(8, 12, 3, 12),
    FcLine(21, 20, 16, 20),
    FcLine(12, 20, 3, 20),
    FcLine(14, 2, 14, 6),
    FcLine(8, 10, 8, 14),
    FcLine(16, 18, 16, 22),
  ]);

  static const FcIcon circleAlert = FcIcon('circleAlert', [
    FcCircle(12, 12, 10),
    FcLine(12, 8, 12, 12),
    FcLine(12, 16, 12.01, 16),
  ]);

  static const FcIcon rotateCw = FcIcon('rotateCw', [
    FcPath('M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8'),
    FcPath('M21 3v5h-5'),
  ]);

  // ---- Lucide (not in the mockups) ----

  static const FcIcon frame = FcIcon('frame', [
    FcLine(22, 6, 2, 6),
    FcLine(22, 18, 2, 18),
    FcLine(6, 2, 6, 22),
    FcLine(18, 2, 18, 22),
  ]);

  static const FcIcon shapes = FcIcon('shapes', [
    FcPath(
      'M8.3 10a.7.7 0 0 1-.626-1.079L11.4 3a.7.7 0 0 1 1.198-.043L16.3 8.9a.7.7 0 0 1-.572 1.1Z',
    ),
    FcRect(3, 14, 7, 7, rx: 1),
    FcCircle(17.5, 17.5, 3.5),
  ]);

  static const FcIcon textAlignStart = FcIcon('textAlignStart', [
    FcPath('M21 5H3'),
    FcPath('M15 12H3'),
    FcPath('M17 19H3'),
  ]);

  static const FcIcon textAlignCenter = FcIcon('textAlignCenter', [
    FcPath('M21 5H3'),
    FcPath('M17 12H7'),
    FcPath('M19 19H5'),
  ]);

  static const FcIcon textAlignEnd = FcIcon('textAlignEnd', [
    FcPath('M21 5H3'),
    FcPath('M21 12H9'),
    FcPath('M21 19H7'),
  ]);

  static const FcIcon triangleAlert = FcIcon('triangleAlert', [
    FcPath(
      'm21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3',
    ),
    FcPath('M12 9v4'),
    FcPath('M12 17h.01'),
  ]);

  static const FcIcon folderOpen = FcIcon('folderOpen', [
    FcPath(
      'm6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2',
    ),
  ]);

  static const FcIcon sun = FcIcon('sun', [
    FcCircle(12, 12, 4),
    FcPath('M12 2v2'),
    FcPath('M12 20v2'),
    FcPath('m4.93 4.93 1.41 1.41'),
    FcPath('m17.66 17.66 1.41 1.41'),
    FcPath('M2 12h2'),
    FcPath('M20 12h2'),
    FcPath('m6.34 17.66-1.41 1.41'),
    FcPath('m19.07 4.93-1.41 1.41'),
  ]);

  static const FcIcon unlink = FcIcon('unlink', [
    FcPath(
      'm18.84 12.25 1.72-1.71h-.02a5.004 5.004 0 0 0-.12-7.07 5.006 5.006 0 0 0-6.95 0l-1.72 1.71',
    ),
    FcPath(
      'm5.17 11.75-1.71 1.71a5.004 5.004 0 0 0 .12 7.07 5.006 5.006 0 0 0 6.95 0l1.71-1.71',
    ),
    FcLine(8, 2, 8, 5),
    FcLine(2, 8, 5, 8),
    FcLine(16, 19, 16, 22),
    FcLine(19, 16, 22, 16),
  ]);

  static const FcIcon fileCode = FcIcon('fileCode', [
    FcPath(
      'M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z',
    ),
    FcPath('M14 2v5a1 1 0 0 0 1 1h5'),
    FcPath('M10 12.5 8 15l2 2.5'),
    FcPath('m14 12.5 2 2.5-2 2.5'),
  ]);

  static const FcIcon x = FcIcon('x', [
    FcPath('M18 6 6 18'),
    FcPath('m6 6 12 12'),
  ]);

  /// Icons the mockups do not show (Lucide, stroke width set to the mockup's 1.75).
  static const List<FcIcon> lucide = [
    frame,
    shapes,
    textAlignStart,
    textAlignCenter,
    textAlignEnd,
    triangleAlert,
    folderOpen,
    sun,
    unlink,
    fileCode,
    x,
  ];

  /// The mockups' own SVGs, in extraction order.
  static const List<FcIcon> mockup = [
    logoMark,
    panelLeft,
    mousePointer2,
    hand,
    square,
    circle,
    diamond,
    triangle,
    stickyNote,
    lineDiagonal,
    arrowUpRight,
    pencil,
    type,
    eraser,
    chevronDown,
    upload,
    strokeNone,
    strokeSolid,
    strokeDashed,
    strokeDotted,
    fillNone,
    fillSolid,
    fillHachure,
    fillCrossHatch,
    code,
    undo2,
    redo2,
    grid3x3,
    moon,
    plus,
    ellipsis,
    trash,
    image,
    fileJson,
    copy,
    download,
    clipboard,
    link,
    slidersHorizontal,
    circleAlert,
    rotateCw,
  ];

  static const List<FcIcon> all = [...mockup, ...lucide];
}

/// A cooked icon: shapes as `Path`s (dashes already applied), built once.
class _Cooked {
  _Cooked(FcIcon icon)
    : parts = [
        for (final s in icon.shapes)
          _Part(_build(s), s.strokeWidth ?? icon.strokeWidth, s.fillOpacity),
      ];

  final List<_Part> parts;

  static ui.Path _build(FcShape s) {
    final p = ui.Path();
    s.addTo(p);
    final dash = s.dash;
    if (dash == null) return p;
    final out = ui.Path();
    for (final m in p.computeMetrics()) {
      var d = 0.0, i = 0;
      while (d < m.length) {
        final len = dash[i % dash.length];
        if (i.isEven) out.addPath(m.extractPath(d, d + len), Offset.zero);
        d += len;
        i++;
      }
    }
    return out;
  }
}

class _Part {
  _Part(this.path, this.strokeWidth, this.fillOpacity);
  final ui.Path path;
  final double strokeWidth;
  final double? fillOpacity;
}

/// Parsed once per icon, for the life of the process.
final Map<FcIcon, _Cooked> _cache = {};

/// Draws an [FcIcon] like [Icon] does: [size] wide (square for the 24x24
/// Lucide icons; other viewBoxes keep their aspect ratio), colour from
/// [color], else the icon's own fixed colour, else `IconTheme`. Excluded from
/// semantics unless [semanticLabel] is given.
class FcIconGlyph extends StatelessWidget {
  const FcIconGlyph(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final FcIcon icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    var c = color ?? icon.color ?? theme.color ?? const Color(0xFF000000);
    final o = theme.opacity;
    if (o != null && o != 1) c = c.withValues(alpha: c.a * o);
    final glyph = SizedBox(
      width: size,
      height: size * icon.height / icon.width,
      child: CustomPaint(painter: _GlyphPainter(icon, c)),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(label: semanticLabel, image: true, child: glyph);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.icon, this.color);

  final FcIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cooked = _cache.putIfAbsent(icon, () => _Cooked(icon));
    canvas.scale(size.width / icon.width, size.height / icon.height);
    // Stroke width is in viewBox units, so the canvas scale handles
    // `strokeWidth * size / viewBox`.
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in cooked.parts) {
      final f = p.fillOpacity;
      if (f != null) {
        canvas.drawPath(
          p.path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: color.a * f),
        );
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..color = color;
      canvas.drawPath(p.path, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.icon != icon || old.color != color;
}

/// Test hook: the cooked (dash-applied) paths of [icon], in viewBox units.
@visibleForTesting
List<ui.Path> fcIconPaths(FcIcon icon) => [
  for (final p in _cache.putIfAbsent(icon, () => _Cooked(icon)).parts) p.path,
];
