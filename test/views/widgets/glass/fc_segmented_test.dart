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
}
