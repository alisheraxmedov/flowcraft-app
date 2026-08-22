import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(SketchController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: ExportMenuButton(controller: controller)),
    ),
  );
}

SketchRectangle _rect() {
  return SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10));
}

MenuItemButton _item(WidgetTester tester, String label) {
  return tester.widget<MenuItemButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(MenuItemButton),
    ),
  );
}

void main() {
  testWidgets('looks like the pill it replaces', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    expect(find.text('Export'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
  });

  testWidgets('opens a menu with the three export routes', (tester) async {
    final controller = SketchController(initialElements: [_rect()]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export as PNG'), findsOneWidget);
    expect(find.text('Export as JSON'), findsOneWidget);
    expect(find.text('Copy JSON to clipboard'), findsOneWidget);
  });

  testWidgets('offers the way back in, next to the way out', (tester) async {
    // `Export as JSON` promises a re-importable file; before these two
    // entries existed the app had no import path at all.
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    // Live even on an empty canvas — importing is how you fill one.
    expect(_item(tester, 'Import from file…').onPressed, isNotNull);
    expect(_item(tester, 'Paste JSON…').onPressed, isNotNull);
  });

  testWidgets('Paste JSON… opens the paste dialog', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste JSON…'));
    await tester.pumpAndSettle();

    expect(find.byType(PasteSceneDialog), findsOneWidget);
  });

  testWidgets('disables file export while the canvas is empty',
      (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(_item(tester, 'Export as PNG').onPressed, isNull);
    expect(_item(tester, 'Export as JSON').onPressed, isNull);
    expect(_item(tester, 'Copy JSON to clipboard').onPressed, isNotNull);
  });

  testWidgets('enables file export as soon as something is drawn',
      (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.add(_rect());
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(_item(tester, 'Export as PNG').onPressed, isNotNull);
  });

  testWidgets('copying puts the serialized scene on the clipboard',
      (tester) async {
    final controller = SketchController(initialElements: [_rect()]);
    addTearDown(controller.dispose);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy JSON to clipboard'));
    await tester.pumpAndSettle();

    expect(copied, contains('"rectangle"'));
    expect(find.text('Copied 1 element as JSON'), findsOneWidget);
  });
}
