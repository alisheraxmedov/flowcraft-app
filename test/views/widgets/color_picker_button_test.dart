import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

Widget _host(SketchController c) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: PropertiesPanel(controller: c),
    ),
  ),
);

void pickerTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await body(tester);
  });
}

Future<SketchController> _open(
  WidgetTester tester, {
  SketchStyle style = const SketchStyle(),
  String chip = 'Pick stroke colour',
}) async {
  final c = SketchController(
    initialElements: [
      SketchRectangle.create(
        id: 'a',
        rect: const Rect.fromLTWH(0, 0, 100, 60),
        style: style,
      ),
    ],
  );
  addTearDown(c.dispose);
  c.select('a');
  await tester.pumpWidget(_host(c));
  await tester.tap(find.byTooltip(chip));
  await tester.pumpAndSettle();
  return c;
}

final _sv = find.byKey(const ValueKey('color_picker_sv'));
final _hue = find.byKey(const ValueKey('color_picker_hue'));

void main() {
  pickerTest('tapping the chip opens the picker', (tester) async {
    await _open(tester);
    expect(_sv, findsOneWidget);
    expect(_hue, findsOneWidget);
  });

  pickerTest('an SV drag recolours live and is one undo step', (tester) async {
    final c = await _open(tester);
    final before = c.elements.single.style.strokeColor;
    final g = await tester.startGesture(
      tester.getTopLeft(_sv) + const Offset(100, 70),
    );
    await tester.pump();
    await g.moveBy(const Offset(40, 20));
    await tester.pump();
    final mid = c.elements.single.style.strokeColor;
    expect(mid, isNot(before));
    await g.moveBy(const Offset(-30, 10));
    await g.up();
    await tester.pump();
    expect(c.elements.single.style.strokeColor, isNot(mid));
    expect(c.elements.single.style.strokeColor.a, 1.0);
    c.undo();
    expect(c.elements.single.style.strokeColor, before);
    expect(c.canUndo, isFalse);
  });

  pickerTest('the hue bar changes the hue', (tester) async {
    final c = await _open(
      tester,
      style: const SketchStyle(strokeColor: Color(0xFFFF0000)),
    );
    await tester.tapAt(tester.getTopLeft(_hue) + const Offset(100, 8));
    await tester.pump();
    final hsv = HSVColor.fromColor(c.elements.single.style.strokeColor);
    expect(hsv.hue, inInclusiveRange(170, 190));
  });

  pickerTest('picking with no fill sets a fill and the hex field follows', (
    tester,
  ) async {
    final c = await _open(tester, chip: 'Pick fill colour');
    expect(c.elements.single.style.fillColor, isNull);
    await tester.tapAt(tester.getTopLeft(_sv) + const Offset(50, 40));
    await tester.pump();
    final fill = c.elements.single.style.fillColor;
    expect(fill, isNotNull);
    final hex =
        '#${(fill!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('properties_hex_Fill')),
    );
    expect(field.controller!.text, hex);
    c.undo();
    expect(c.elements.single.style.fillColor, isNull);
  });

  pickerTest('the picker opens beside the inspector, not over its fields', (
    tester,
  ) async {
    await _open(tester, chip: 'Pick fill colour');
    final inspector = tester.getRect(find.byType(PropertiesPanel));
    expect(tester.getTopLeft(_sv).dx, greaterThanOrEqualTo(inspector.right));
  });
}
