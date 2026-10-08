import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/views/widgets/glass/fc_icon_button.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/toolbar/tool_button.dart';

Widget _host(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

BoxDecoration _chip(WidgetTester tester, Finder f) =>
    tester
            .widget<Container>(
              find.descendant(of: f, matching: find.byType(Container)).first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  for (final (name, theme, t) in [
    ('light', AppTheme.light(), FcTokens.light),
    ('dark', AppTheme.dark(), FcTokens.dark),
  ]) {
    group(name, () {
      testWidgets(
        'selected tool button has raised fill, no border, accentText icon',
        (tester) async {
          await tester.pumpWidget(
            _host(
              ToolButton(
                tool: SketchTool.rectangle,
                selected: true,
                onTap: () {},
              ),
              theme,
            ),
          );
          await tester.pumpAndSettle();
          final box = tester.widget<AnimatedContainer>(
            find.byType(AnimatedContainer),
          );
          final d = box.decoration! as BoxDecoration;
          expect(d.color, t.raised);
          expect(d.border, isNull);
          expect(d.boxShadow, t.raisedShadow);
          expect(d.borderRadius, BorderRadius.circular(12));
          expect(tester.getSize(find.byType(AnimatedContainer)).width, 40);
          final glass = tester.widget<FcIconGlyph>(find.byType(FcIconGlyph));
          expect(glass.color, t.accentText);
        },
      );

      testWidgets('Grid toggle pressed uses the same raised chip', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            FcIconButton(
              icon: FcIcons.grid3x3,
              tooltip: 'Grid',
              pressed: true,
              onPressed: () {},
            ),
            theme,
          ),
        );
        final d = _chip(tester, find.byType(FcIconButton));
        expect(d.color, t.raised);
        expect(d.border, isNull);
        expect(d.boxShadow, t.raisedShadow);
        expect(d.borderRadius, BorderRadius.circular(10));
        expect(tester.getSize(find.byType(FcIconButton)), const Size(36, 36));
        expect(
          tester.widget<FcIconGlyph>(find.byType(FcIconGlyph)).color,
          t.accentText,
        );
      });

      testWidgets('tool tooltip pill matches the tokens', (tester) async {
        await tester.pumpWidget(
          _host(
            ToolButton(
              tool: SketchTool.rectangle,
              selected: false,
              onTap: () {},
            ),
            theme,
          ),
        );
        final tip = tester.widget<Tooltip>(find.byType(Tooltip));
        final d = tip.decoration! as BoxDecoration;
        expect(d.color, const Color(0xFF2A2A2E));
        expect(d.borderRadius, BorderRadius.circular(8));
        expect(d.boxShadow!.single.color, const Color(0x40000000));
        expect(d.boxShadow!.single.blurRadius, 16);
        expect(d.boxShadow!.single.offset, const Offset(0, 6));
        expect(tip.verticalOffset, 30);
        final th = Theme.of(tester.element(find.byType(Tooltip))).tooltipTheme;
        expect(th.constraints!.minHeight, 28);
        expect(th.textStyle!.fontSize, 12);
        expect(th.textStyle!.fontWeight, FontWeight.w500);
        expect(th.textStyle!.color, const Color(0xFFF5F5F7));
      });
    });
  }

  test('fillSolid preview fill is 35% alpha', () {
    for (final s in FcIcons.fillSolid.shapes) {
      expect(s.fillOpacity, 0.35);
    }
    for (final i in [
      FcIcons.fillNone,
      FcIcons.fillHachure,
      FcIcons.fillCrossHatch,
    ]) {
      expect(
        i.shapes.every((s) => s.fillOpacity == null),
        isTrue,
        reason: i.name,
      );
    }
  });

  testWidgets('slider thumb is 16px, no ticks, no value indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Slider(value: 2, min: 1, max: 12, onChanged: (_) {}),
        AppTheme.light(),
      ),
    );
    final th = SliderTheme.of(tester.element(find.byType(Slider)));
    final thumb = th.thumbShape! as RoundSliderThumbShape;
    expect(thumb.enabledThumbRadius * 2, 16);
    expect(th.trackHeight, 4);
    expect(th.tickMarkShape, SliderTickMarkShape.noTickMark);
    expect(th.showValueIndicator, ShowValueIndicator.never);
    expect(th.activeTrackColor, FcTokens.light.accent);
  });
}
