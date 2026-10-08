import 'dart:io';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/insert_image_dialog.dart';
import 'package:flutter/material.dart';
import 'glass_surface_expect.dart';
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
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton)),
  );
}

void main() {
  testWidgets('is the accent-filled pill with the upload glyph', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));

    expect(find.text('Export'), findsOneWidget);
    final pill = tester.widget<Container>(
      find
          .ancestor(of: find.text('Export'), matching: find.byType(Container))
          .first,
    );
    expect((pill.decoration! as BoxDecoration).color, FcTokens.light.accent);
    expect(tester.getSize(find.byType(ExportMenuButton)).height, 32);
    final glyph = tester.widget<FcIconGlyph>(find.byType(FcIconGlyph));
    expect(glyph.icon, same(FcIcons.upload));
    expect(glyph.size, 16);
  });

  testWidgets('the menu ends with the "Saves to" footer note', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Saves to ~/Documents/FlowCraft'), findsOneWidget);
    final png = find.ancestor(
      of: find.text('Export as PNG'),
      matching: find.byType(MenuItemButton),
    );
    expect(tester.getSize(png).height, 34, reason: 'mockup rows are h34');
  });

  testWidgets('menu surface is glass-strong, radius 14, bordered, shadowed', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expectGlassSurface(tester, find.text('Export as PNG'), radius: 14);
  });

  testWidgets('Insert image from file… opens the dialog', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert image from file…'));
    await tester.pumpAndSettle();

    expect(find.byType(InsertImageDialog), findsOneWidget);
  });

  testWidgets('opens a menu with the three export routes', (tester) async {
    final controller = SketchController(initialElements: [_rect()]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export as PNG'), findsOneWidget);
    expect(find.text('Export as SVG'), findsOneWidget);
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
    expect(_item(tester, 'Paste JSON, Mermaid, DBML…').onPressed, isNotNull);
  });

  testWidgets('Paste JSON, Mermaid, DBML… opens the paste dialog', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste JSON, Mermaid, DBML…'));
    await tester.pumpAndSettle();

    expect(find.byType(PasteSceneDialog), findsOneWidget);
  });

  testWidgets('disables file export while the canvas is empty', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(_item(tester, 'Export as PNG').onPressed, isNull);
    expect(_item(tester, 'Export as JSON').onPressed, isNull);
    expect(_item(tester, 'Copy JSON to clipboard').onPressed, isNotNull);
  });

  testWidgets('enables file export as soon as something is drawn', (
    tester,
  ) async {
    final controller = SketchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    controller.add(_rect());
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(_item(tester, 'Export as PNG').onPressed, isNotNull);
  });

  testWidgets('copying puts the serialized scene on the clipboard', (
    tester,
  ) async {
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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_host(controller));
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy JSON to clipboard'));
    await tester.pumpAndSettle();

    expect(copied, contains('"rectangle"'));
    expect(find.text('Copied 1 element as JSON'), findsOneWidget);
  });

  testWidgets('Export as SVG writes an .svg file', (tester) async {
    final controller = SketchController(initialElements: [_rect()]);
    addTearDown(controller.dispose);
    final dir = Directory.systemTemp.createTempSync('export_menu_');
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExportMenuButton(
              controller: controller,
              exportDirectory: dir.path,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    // Real file IO only completes when started *and* awaited inside
    // runAsync; the fake-async zone never services its callbacks.
    await tester.tap(find.text('Export as SVG'));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && dir.listSync().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();

    final files = dir.listSync();
    expect(files, hasLength(1));
    expect(files.single.path, endsWith('.svg'));
    expect(File(files.single.path).readAsStringSync(), startsWith('<svg'));
  });
}
