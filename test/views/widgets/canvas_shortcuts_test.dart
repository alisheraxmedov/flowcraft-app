import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SketchRectangle _rect(String id, {double x = 0}) {
  return SketchRectangle.create(id: id, rect: Rect.fromLTWH(x, 0, 10, 10));
}

/// The screen shape this layer is built for: something focusable inside it
/// (the canvas, in the real app), plus whatever the test wants beside it.
///
/// [platform] goes through `ThemeData` rather than
/// `debugDefaultTargetPlatformOverride` — the binding asserts that foundation
/// debug variables come back unset, and the shortcut table reads
/// `Theme.of(context).platform` anyway.
Widget _host(
  SketchController controller, {
  Widget? beside,
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: CanvasShortcuts(
        controller: controller,
        child: Column(
          children: [
            const Focus(
              autofocus: true,
              child: SizedBox(width: 100, height: 100),
            ),
            if (beside != null) SizedBox(width: 300, child: beside),
          ],
        ),
      ),
    ),
  );
}

/// The real inline editor inside the layer, the way the whiteboard has it.
Widget _hostWithEditor(SketchController controller) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: CanvasShortcuts(
        controller: controller,
        child: Stack(
          children: [
            const Focus(
              autofocus: true,
              child: SizedBox(width: 100, height: 100),
            ),
            SketchTextEditor(
              controller: controller,
              viewport: const FlowViewport(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Holds [modifier] down for one keystroke, the way a real chord arrives.
Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? second,
}) async {
  await tester.sendKeyDownEvent(modifier);
  if (second != null) await tester.sendKeyDownEvent(second);
  await tester.sendKeyEvent(key);
  if (second != null) await tester.sendKeyUpEvent(second);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  group('tool keys', () {
    testWidgets('single letters pick tools, Excalidraw-style', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      for (final (key, tool) in <(LogicalKeyboardKey, SketchTool)>[
        (LogicalKeyboardKey.keyR, SketchTool.rectangle),
        (LogicalKeyboardKey.keyO, SketchTool.ellipse),
        (LogicalKeyboardKey.keyD, SketchTool.diamond),
        (LogicalKeyboardKey.keyL, SketchTool.line),
        (LogicalKeyboardKey.keyA, SketchTool.arrow),
        (LogicalKeyboardKey.keyP, SketchTool.freedraw),
        (LogicalKeyboardKey.keyT, SketchTool.text),
        (LogicalKeyboardKey.keyE, SketchTool.eraser),
        (LogicalKeyboardKey.keyN, SketchTool.sticky),
        (LogicalKeyboardKey.keyG, SketchTool.triangle),
        (LogicalKeyboardKey.keyH, SketchTool.hand),
        (LogicalKeyboardKey.keyV, SketchTool.select),
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(controller.currentTool, tool, reason: 'pressing ${key.keyLabel}');
      }
    });

    testWidgets('a modifier held turns a tool key back into a command',
        (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      // ⌘D is duplicate, not "pick the diamond tool".
      controller.select('a');
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyD);

      expect(controller.currentTool, SketchTool.select);
      expect(controller.elements, hasLength(2));
    });
  });

  testWidgets('shortcuts survive focus leaving the canvas', (tester) async {
    // The bug this layer exists to fix: the old handler hung off the
    // canvas's own focus node, so clicking a toolbar popover or a panel
    // control killed every shortcut until you clicked the canvas again.
    final controller = SketchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      controller,
      beside: ElevatedButton(onPressed: () {}, child: const Text('elsewhere')),
    ));

    await tester.tap(find.text('elsewhere'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(controller.currentTool, SketchTool.rectangle);
  });

  group('shortcuts come back the moment typing ends', () {
    // `FocusNode.unfocus()` — which every field calls on Enter/Escape and
    // the inline editor on commit — parks focus on the nearest enclosing
    // scope. Without a scope of its own inside the layer, that was the
    // route's scope *above* `Shortcuts`, and every key went dead until the
    // canvas was clicked again.
    Future<SketchController> editing(WidgetTester tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      controller.add(SketchText.create(
        id: 't',
        position: Offset.zero,
        text: 'hello',
        fontSize: 16,
      ));
      await tester.pumpWidget(_hostWithEditor(controller));
      controller.beginTextEdit(elementId: 't');
      await tester.pump();
      await tester.pump();
      expect(controller.editingElementId, 't');
      return controller;
    }

    testWidgets('a tool key works after the inline editor commits with Enter',
        (tester) async {
      final controller = await editing(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.editingElementId, isNull, reason: 'precondition');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(controller.currentTool, SketchTool.rectangle);
    });

    testWidgets('a tool key works after the inline editor cancels with Escape',
        (tester) async {
      final controller = await editing(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.editingElementId, isNull, reason: 'precondition');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(controller.currentTool, SketchTool.rectangle);
    });

    testWidgets('a tool key works after Enter in a properties-style field',
        (tester) async {
      // `TextField` unfocuses itself on `TextInputAction.done` — the
      // properties panel's X/Y/W/H and hex fields, and the project title.
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, beside: const TextField()));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(controller.currentTool, SketchTool.rectangle);
    });
  });

  testWidgets('Escape abandons an open text edit', (tester) async {
    // The intent's doc promises it; an edit whose editor has lost focus
    // (Tab) has nothing else left that can close it.
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    controller.select('a');
    controller.beginTextEdit(elementId: 'a');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.editingElementId, isNull);
    expect(controller.selectedIds, isEmpty);
  });

  group('typing must not fire canvas shortcuts', () {
    testWidgets('a tool letter typed into a field leaves the tool alone',
        (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, beside: const TextField()));

      // Same key, twice, differing only in where focus is — which is the
      // whole claim being tested.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(controller.currentTool, SketchTool.rectangle,
          reason: 'precondition: the shortcut works when not typing');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.pump();

      expect(controller.currentTool, SketchTool.rectangle);
    });

    testWidgets('Backspace in a field does not delete the selection',
        (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, beside: const TextField()));
      controller.select('a');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.elements, hasLength(1));
    });

    testWidgets('⌘A in a field does not select every element',
        (tester) async {
      final controller =
          SketchController(initialElements: [_rect('a'), _rect('b', x: 40)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, beside: const TextField()));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyA);

      expect(controller.selectedIds, isEmpty);
    });

    testWidgets('the canvas text editor counts as typing too', (tester) async {
      // The inline editor is a bare `EditableText`, not a `TextField`; the
      // guard has to recognise both.
      final controller = SketchController();
      addTearDown(controller.dispose);
      final text = TextEditingController();
      addTearDown(text.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(_host(
        controller,
        beside: EditableText(
          controller: text,
          focusNode: focus,
          style: const TextStyle(),
          cursorColor: const Color(0xFF000000),
          backgroundCursorColor: const Color(0xFF000000),
        ),
      ));
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(controller.currentTool, SketchTool.select);
    });
  });

  group('edit, history and arrange', () {
    testWidgets('⌘Z undoes and ⇧⌘Z redoes', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      controller.add(_rect('a'));

      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyZ);
      expect(controller.elements, isEmpty);

      await _chord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.keyZ,
        second: LogicalKeyboardKey.shiftLeft,
      );
      expect(controller.elements, hasLength(1));
    });

    testWidgets('Delete removes the selection and Escape drops it',
        (tester) async {
      final controller =
          SketchController(initialElements: [_rect('a'), _rect('b', x: 40)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));

      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyA);
      expect(controller.selectedIds, hasLength(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.selectedIds, isEmpty);

      controller.select('a');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(controller.elements.single.id, 'b');
    });

    testWidgets('⌘] moves the selection up the stack', (tester) async {
      final controller =
          SketchController(initialElements: [_rect('a'), _rect('b', x: 40)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      controller.select('a');

      await _chord(tester, LogicalKeyboardKey.metaLeft,
          LogicalKeyboardKey.bracketRight);

      expect(controller.elements.map((e) => e.id), ['b', 'a']);
    });

    testWidgets('⌘G groups and ⇧⌘G ungroups', (tester) async {
      final controller =
          SketchController(initialElements: [_rect('a'), _rect('b', x: 40)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      controller.selectMany(['a', 'b']);

      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyG);
      expect(controller.elements.first.groupId, isNotNull);

      await _chord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.keyG,
        second: LogicalKeyboardKey.shiftLeft,
      );
      expect(controller.elements.first.groupId, isNull);
    });
  });

  group('clipboard', () {
    /// Stands in for the platform clipboard, so a copy in one window and a
    /// paste in another can be told apart from an in-app buffer.
    String? mockClipboard(WidgetTester tester, {String? holding}) {
      String? written = holding;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            written = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') {
            return written == null ? null : <String, Object?>{'text': written};
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      return written;
    }

    testWidgets('⌘C writes the selection as a scene payload', (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
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
      controller.select('a');
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      expect(copied, contains('"rectangle"'));
      expect(controller.elements, hasLength(1), reason: 'copy is not cut');
    });

    testWidgets('⌘X removes only once the copy has landed', (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
      addTearDown(controller.dispose);
      mockClipboard(tester);

      await tester.pumpWidget(_host(controller));
      controller.select('a');
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();

      expect(controller.elements, isEmpty);
    });

    testWidgets('⌘V adds whatever scene the clipboard holds', (tester) async {
      final controller = SketchController();
      addTearDown(controller.dispose);
      mockClipboard(tester,
          holding: SketchSerializer.serialize([_rect('from-elsewhere')]));

      await tester.pumpWidget(_host(controller));
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(controller.elements, hasLength(1));
    });

    testWidgets('⌘V over arbitrary text does nothing at all', (tester) async {
      // The clipboard holds whatever the user last copied anywhere — a
      // paste of a shopping list must be a no-op, not an exception.
      final controller = SketchController();
      addTearDown(controller.dispose);
      mockClipboard(tester, holding: 'milk, eggs, bread');

      await tester.pumpWidget(_host(controller));
      await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(controller.elements, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('nudge', () {
    testWidgets('arrows move by 1px and Shift+arrows by 10', (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      controller.select('a');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.elements.single.bounds.left, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.elements.single.bounds.top, 10);
    });

    testWidgets('a run of nudges collapses into one undo entry',
        (tester) async {
      final controller = SketchController(initialElements: [_rect('a')]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      controller.select('a');

      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(controller.elements.single.bounds.left, 5);

      // Past the coalescing window, so the run is closed.
      await tester.pump(const Duration(milliseconds: 400));
      controller.undo();

      expect(controller.elements.single.bounds.left, 0);
    });
  });

  testWidgets('? opens the reference sheet', (tester) async {
    final controller = SketchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
    await tester.pumpAndSettle();

    expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    expect(find.text('Rectangle'), findsOneWidget);
    expect(find.text('Bring to front'), findsOneWidget);
  });

  testWidgets('Ctrl is the modifier away from Apple platforms',
      (tester) async {
    final controller = SketchController(initialElements: [_rect('a')]);
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(_host(controller, platform: TargetPlatform.linux));
    controller.select('a');

    await _chord(
        tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyD);

    expect(controller.elements, hasLength(2));
  });
}
