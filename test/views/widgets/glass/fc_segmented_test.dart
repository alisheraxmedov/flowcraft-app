import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/views/widgets/glass/fc_segmented.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap selects; selected segment exposes Semantics selected', (
    tester,
  ) async {
    var v = 'a';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) => FcSegmented<String>(
              value: v,
              options: const {'a': 'Alpha', 'b': 'Beta'},
              onChanged: (n) => set(() => v = n),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Alpha')),
      matchesSemantics(
        label: 'Alpha',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(v, 'b');
    expect(
      tester.getSemantics(find.text('Beta')),
      matchesSemantics(
        label: 'Beta',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('custom height/gap/inactiveColor are applied', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FcSegmented<String>(
            value: 'a',
            options: const {'a': 'Alpha', 'b': 'Beta'},
            onChanged: (_) {},
            height: 34,
            gap: 2,
            inactiveColor: const Color(0xFF123456),
          ),
        ),
      ),
    );
    final a = tester.getRect(
      find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Container))
          .first,
    );
    final b = tester.getRect(
      find
          .ancestor(of: find.text('Beta'), matching: find.byType(Container))
          .first,
    );
    expect(a.height, 34);
    expect(b.left - a.right, 2);
    expect(
      tester.widget<Text>(find.text('Beta')).style!.color,
      const Color(0xFF123456),
    );
  });
}
