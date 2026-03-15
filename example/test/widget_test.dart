import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft_example/main.dart';

void main() {
  testWidgets('renders the FlowCraft demo canvas', (tester) async {
    await tester.pumpWidget(const FlowCraftExampleApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FlowCanvas), findsOneWidget);
    expect(find.text('FlowCraft Demo'), findsOneWidget);
    expect(find.text('Trigger'), findsOneWidget);
    expect(find.text('Deliver'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_box_outlined));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 5'), findsOneWidget);
  });
}
