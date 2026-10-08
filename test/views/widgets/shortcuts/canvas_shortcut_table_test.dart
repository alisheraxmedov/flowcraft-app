import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two activators collide when they would accept the same keystroke.
///
/// `SingleActivator` has no `==`, so a duplicate key in the bindings map is
/// not a compile error and not a runtime one — the second binding simply
/// never fires. This is the shape of the bug that catch.
String _fingerprint(ShortcutActivator activator) {
  if (activator is SingleActivator) {
    return '${activator.trigger.keyId}'
        '/${activator.control}/${activator.shift}'
        '/${activator.alt}/${activator.meta}';
  }
  if (activator is CharacterActivator) return 'char:${activator.character}';
  return activator.toString();
}

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
    group('$platform', () {
      test('no two commands claim the same keystroke', () {
        final seen = <String, String>{};
        for (final group in CanvasShortcutTable.groups(platform)) {
          for (final shortcut in group.shortcuts) {
            final key = _fingerprint(shortcut.activator);
            final owner = seen[key];
            expect(
              owner,
              anyOf(isNull, shortcut.label),
              reason:
                  '$key is claimed by both "$owner" and '
                  '"${shortcut.label}"',
            );
            seen[key] = shortcut.label;
          }
        }
      });

      test('zoom, align and distribute are bound and listed in the menu', () {
        final labels = {
          for (final g in CanvasShortcutTable.menuGroups(platform))
            for (final s in g.shortcuts) s.label,
        };
        expect(
          labels,
          containsAll([
            'Zoom to fit',
            'Align left',
            'Align right',
            'Align top',
            'Align bottom',
            'Center horizontally',
            'Center vertically',
            'Distribute horizontally',
            'Distribute vertically',
          ]),
        );
      });

      test('every tool is reachable from the keyboard', () {
        final bound = <SketchTool>{
          for (final group in CanvasShortcutTable.groups(platform))
            for (final shortcut in group.shortcuts)
              if (shortcut.intent case SelectToolIntent(:final tool)) tool,
        };

        expect(bound, SketchTool.values.toSet());
      });

      test('the menu takes the commands, not the tool keys', () {
        final titles = CanvasShortcutTable.menuGroups(
          platform,
        ).map((g) => g.title);

        expect(titles, contains('Edit'));
        expect(titles, isNot(contains('Tools')));
        expect(titles, isNot(contains('Move selection')));
      });

      test('the menu lists a twice-bound command once', () {
        final edit = CanvasShortcutTable.menuGroups(
          platform,
        ).firstWhere((g) => g.title == 'Edit');

        expect(edit.shortcuts.where((s) => s.label == 'Delete'), hasLength(1));
      });
    });
  }

  test('the primary modifier follows the platform', () {
    SingleActivator copyOn(TargetPlatform platform) {
      return CanvasShortcutTable.groups(platform)
              .firstWhere((g) => g.title == 'Edit')
              .shortcuts
              .firstWhere((s) => s.label == 'Copy')
              .activator
          as SingleActivator;
    }

    expect(copyOn(TargetPlatform.macOS).meta, isTrue);
    expect(copyOn(TargetPlatform.macOS).control, isFalse);
    expect(copyOn(TargetPlatform.windows).control, isTrue);
    expect(copyOn(TargetPlatform.windows).meta, isFalse);
  });

  group('modifier hints', () {
    // Shift-click, Shift-resize, Alt-to-unsnap and the editor's own keys
    // are real behaviour that lives outside the bindings map; the sheet
    // used to claim "every shortcut" and leave them all out.
    test('are display-only and never reach the bindings', () {
      final hints = CanvasShortcutTable.modifierGroups(TargetPlatform.linux);
      expect(hints, isNotEmpty);
      expect(hints.expand((g) => g.hints), isNotEmpty);
      // Nothing in them can be bound: no activator, no intent.
      final bound = CanvasShortcutTable.bindings(TargetPlatform.linux).length;
      final listed = CanvasShortcutTable.groups(
        TargetPlatform.linux,
      ).expand((g) => g.shortcuts).length;
      expect(bound, listed);
    });

    test('spell the modifiers the way the platform does', () {
      String keysOf(TargetPlatform p) => CanvasShortcutTable.modifierGroups(
        p,
      ).expand((g) => g.hints).map((h) => h.keys).join(' ');

      expect(keysOf(TargetPlatform.macOS), contains('⇧'));
      expect(keysOf(TargetPlatform.macOS), contains('⌥'));
      expect(keysOf(TargetPlatform.linux), contains('Shift'));
      expect(keysOf(TargetPlatform.linux), contains('Alt'));
    });

    testWidgets('the reference sheet shows them', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: const Scaffold(body: ShortcutsHelpDialog()),
        ),
      );

      expect(find.textContaining('Shift'), findsWidgets);
      expect(find.textContaining('Alt'), findsWidgets);
      expect(find.text('Disable snapping while dragging'), findsOneWidget);
      expect(find.text('Keep aspect ratio while resizing'), findsOneWidget);
      expect(find.text('WHILE EDITING TEXT'), findsOneWidget);
    });
  });

  group('labels', () {
    test('write chords the way each platform prints them', () {
      const copy = SingleActivator(LogicalKeyboardKey.keyC, meta: true);
      const redo = SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      );

      expect(ShortcutLabel.of(copy, TargetPlatform.macOS), '⌘C');
      expect(ShortcutLabel.of(redo, TargetPlatform.linux), 'Ctrl+Shift+Z');
    });

    test('fold commands bound twice into one row', () {
      // Delete answers both Del and Backspace; two rows would read as two
      // different commands.
      final rows = ShortcutLabel.merge(
        CanvasShortcutTable.groups(
          TargetPlatform.macOS,
        ).firstWhere((g) => g.title == 'Edit').shortcuts,
        TargetPlatform.macOS,
      );

      expect(rows.firstWhere((r) => r.label == 'Delete').keys, 'Del / ⌫');
    });
  });
}
