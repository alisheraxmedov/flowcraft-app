import 'dart:math' as math;
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
}
