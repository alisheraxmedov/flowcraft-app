import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

import 'package:flowcraft_example/main.dart';

void main() {
  testWidgets('whiteboard app builds and renders the sketch toolbar',
      (tester) async {
    await tester.pumpWidget(const FlowCraftWhiteboardApp());

    expect(find.byType(WhiteboardCanvas), findsOneWidget);
    expect(find.byType(SketchToolbarRich), findsOneWidget);
  });
}
