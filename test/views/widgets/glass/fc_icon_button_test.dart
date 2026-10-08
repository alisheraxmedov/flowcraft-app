import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/views/widgets/glass/fc_icon_button.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

void main() {
  Widget host(FcIconButton b) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: b)),
  );

  testWidgets('renders the FcIcon glyph, fires onPressed, tooltip set', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        FcIconButton(
          icon: FcIcons.undo2,
          tooltip: 'Undo',
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.byType(FcIconGlyph), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    await tester.tap(find.byType(FcIconButton));
    expect(taps, 1);
  });

  testWidgets('null onPressed disables it', (tester) async {
    await tester.pumpWidget(
      host(const FcIconButton(icon: FcIcons.redo2, tooltip: 'Redo')),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.35);
  });
}
