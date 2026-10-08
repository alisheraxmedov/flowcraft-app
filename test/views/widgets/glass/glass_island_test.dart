import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(FcTokens t) {
  final base = AppTheme.light();
  return MaterialApp(
    theme: base.copyWith(extensions: [t]),
    home: const Scaffold(body: GlassIsland(child: Text('hi'))),
  );
}

void main() {
  testWidgets('renders child and blurs when sigma > 0', (tester) async {
    await tester.pumpWidget(_app(FcTokens.light));
    expect(find.text('hi'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('sigma 0 drops the BackdropFilter', (tester) async {
    await tester.pumpWidget(_app(FcTokens.light.copyWith(blurSigma: 0)));
    expect(find.text('hi'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
