import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/services/svg_exporter.dart';

SketchRectangle _rect({
  SketchStyle style = const SketchStyle(),
  String? text,
  double fontSize = 16,
  double angle = 0,
}) => SketchRectangle.create(
  rect: const Rect.fromLTWH(10, 20, 100, 60),
  style: style,
  text: text,
  fontSize: fontSize,
).copyWith(angle: angle);

void main() {
  test('empty → valid svg with viewBox', () async {
    final svg = await SvgExporter.render(const []);
    expect(svg, startsWith('<svg'));
    expect(svg, contains('viewBox="-32 -32 64 64"'));
    expect(svg, endsWith('</svg>'));
  });

  test('rectangle: stroked path, no fill', () async {
    final svg = await SvgExporter.render([_rect()]);
    expect(svg, contains('fill="none"'));
    expect(svg, contains('stroke="#1e1e1e"'));
    expect(svg, contains('viewBox="-22 -12 164 124"'));
    expect(RegExp(r'<path ').allMatches(svg).length, 1);
  });

  test('solid fill is filled', () async {
    final svg = await SvgExporter.render([
      _rect(
        style: const SketchStyle(
          fillColor: Color(0xFFFF0000),
          fillStyle: FillStyle.solid,
        ),
      ),
    ]);
    expect(svg, contains('fill="#ff0000"'));
  });

  test('text → <text>', () async {
    final svg = await SvgExporter.render([
      SketchText.create(position: const Offset(5, 5), text: 'hello'),
    ]);
    expect(svg, contains('<text font-family="Inter, sans-serif"'));
    expect(svg, contains('>hello</tspan>'));
  });

  test('arrow → head path', () async {
    final svg = await SvgExporter.render([
      SketchArrow.create(start: Offset.zero, end: const Offset(100, 0)),
    ]);
    // Stroke path + filled head.
    expect(RegExp(r'<path ').allMatches(svg).length, 2);
    expect(RegExp(r'<path d="[^"]*" fill="#1e1e1e"').hasMatch(svg), isTrue);
  });

  test('labels with & < > are escaped', () async {
    final svg = await SvgExporter.render([_rect(text: 'a&b<c>"', fontSize: 8)]);
    expect(svg, contains('a&amp;b&lt;c&gt;&quot;'));
    expect(svg, isNot(contains('<b>')));
  });

  test('dashed stroke → multiple contours', () async {
    final svg = await SvgExporter.render([
      _rect(style: const SketchStyle(strokeStyle: StrokeStyle.dashed)),
    ]);
    final d = RegExp(r'd="([^"]*)"').firstMatch(svg)!.group(1)!;
    expect('M'.allMatches(d).length, greaterThan(1));
  });

  test('rotation emits transform', () async {
    final svg = await SvgExporter.render([_rect(angle: math.pi / 2)]);
    expect(svg, contains('transform="rotate(90 60 50)"'));
  });

  test('frame emits rect + name', () async {
    final svg = await SvgExporter.render([
      SketchFrame.create(
        rect: const Rect.fromLTWH(0, 0, 200, 100),
        name: 'Backend',
      ),
    ]);
    expect(svg, contains('<rect x="0" y="0" width="200" height="100"'));
    expect(svg, contains('stroke-width="1"'));
    expect(svg, contains('>Backend</tspan>'));
  });

  test('icon emits <image>', () async {
    final svg = await SvgExporter.render([
      SketchIcon.create(
        rect: const Rect.fromLTWH(0, 0, 64, 64),
        name: 'database',
      ),
    ]);
    expect(svg, contains('<image '));
    expect(svg, contains('href="data:image/png;base64,'));
  });

  test('image emits data URI with its mime', () async {
    final svg = await SvgExporter.render([
      SketchImage.create(
        rect: const Rect.fromLTWH(0, 0, 40, 30),
        mimeType: 'image/webp',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ]);
    expect(svg, contains('href="data:image/webp;base64,AQIDBA=="'));
    expect(svg, contains('width="40" height="30"'));
  });

  test('entity emits a row per attribute', () async {
    final svg = await SvgExporter.render([
      SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 220, 0),
        name: 'user',
        attributes: const [
          EntityAttribute(name: 'id', type: 'int', primaryKey: true),
          EntityAttribute(name: 'email', type: 'text'),
          EntityAttribute(name: 'team_id', foreignKey: true),
        ],
      ),
    ]);
    // Header + one <text> per row.
    expect('<text '.allMatches(svg).length, 4);
    expect(svg, contains('>PK</tspan>'));
    expect(svg, contains('>FK</tspan>'));
    expect(svg, contains('>email</tspan>'));
    expect(svg, contains('JetBrains Mono, monospace'));
    expect(svg, contains('text-anchor="end"'));
  });

  test('elbow arrow emits multi-segment path', () async {
    final svg = await SvgExporter.render([
      SketchArrow.create(
        start: Offset.zero,
        end: const Offset(100, 60),
        style: const SketchStyle(roughness: 0),
        elbowed: true,
      ),
    ]);
    final d = RegExp(r'd="(M[^"]*)"').firstMatch(svg)!.group(1)!;
    // Bend corners are on the polyline: (50,0) and (50,60).
    expect(d, contains('50 0'));
    expect(d, contains('50 60'));
    expect('L'.allMatches(d).length, greaterThan(10));
  });

  test("crow's-foot head emits path", () async {
    final svg = await SvgExporter.render([
      SketchArrow.create(
        start: Offset.zero,
        end: const Offset(100, 0),
        endHead: ArrowheadStyle.zeroOrMany,
        startHead: ArrowheadStyle.one,
      ),
    ]);
    // Shaft + two glyph paths, glyphs as unfilled strokes.
    expect('<path '.allMatches(svg).length, 3);
    expect('fill="none"'.allMatches(svg).length, 3);
  });

  test('bold/mono/align attributes', () async {
    final svg = await SvgExporter.render([
      SketchText.create(
        position: Offset.zero,
        text: 'a longer line\nhi',
        fontFamily: 'mono',
        bold: true,
        align: TextAlign.center,
      ),
    ]);
    expect(svg, contains('font-family="JetBrains Mono, monospace"'));
    expect(svg, contains('font-weight="bold"'));
    expect(svg, contains('text-anchor="middle"'));
    final plain = await SvgExporter.render([
      SketchText.create(position: Offset.zero, text: 'x'),
    ]);
    expect(plain, contains('font-family="Inter, sans-serif"'));
    expect(plain, isNot(contains('font-weight')));
    expect(plain, isNot(contains('text-anchor')));
  });
}
