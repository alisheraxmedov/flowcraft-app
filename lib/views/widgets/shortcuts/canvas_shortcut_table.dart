import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, immutable;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show CharacterActivator, Intent, Offset, ShortcutActivator, SingleActivator;

import 'package:flowcraft/views/widgets/shortcuts/canvas_intents.dart';
import 'package:flowcraft/views/widgets/shortcuts/tool_shortcuts.dart';

/// One keystroke and what it means, in the words shown to the user.
@immutable
class CanvasShortcut {
  const CanvasShortcut(this.label, this.activator, this.intent);

  final String label;
  final ShortcutActivator activator;
  final Intent intent;
}

/// A titled block of the reference sheet.
@immutable
class CanvasShortcutGroup {
  const CanvasShortcutGroup(this.title, this.shortcuts, {this.inMenu = true});

  final String title;
  final List<CanvasShortcut> shortcuts;

  /// Whether the top-bar Edit menu should offer this group.
  ///
  /// False for the two groups a menu would only make worse: tools already
  /// have the tool rail, and "nudge by one pixel" is not something anyone
  /// reaches for through three clicks.
  final bool inMenu;
}

/// A keyboard behaviour the reference sheet explains but that is not a
/// bindable keystroke: a modifier held during a pointer gesture, or a key
/// the inline text editor answers to itself.
///
/// Display-only by construction — it carries no activator and no intent, so
/// it can never land in the `Shortcuts` map or the Edit menu.
@immutable
class CanvasModifierHint {
  const CanvasModifierHint(this.label, this.keys);

  final String label;

  /// Already platform-spelled ("⇧ click" / "Shift+click").
  final String keys;
}

/// A titled block of display-only hints. See [CanvasModifierHint].
@immutable
class CanvasModifierGroup {
  const CanvasModifierGroup(this.title, this.hints);

  final String title;
  final List<CanvasModifierHint> hints;
}

/// Every canvas shortcut, in one place.
///
/// The `Shortcuts` map, the `?` reference sheet and the top-bar Edit menu
/// are all derived from this list rather than each spelling the bindings out
/// again — a reference sheet that has drifted from the real bindings is
/// worse than none, because it is believed.
class CanvasShortcutTable {
  CanvasShortcutTable._();

  /// Distance a plain arrow key moves the selection, in canvas pixels.
  static const double nudgeStep = 1;

  /// …and with Shift held.
  static const double nudgeStepCoarse = 10;

  /// The table for [platform], defaulting to the platform actually running.
  ///
  /// Platform-dependent because the primary modifier is Cmd on Apple and
  /// Ctrl everywhere else; hardcoding one makes half the desktop builds feel
  /// broken to anyone who has ever used another app.
  static List<CanvasShortcutGroup> groups([TargetPlatform? platform]) {
    final apple = _isApple(platform ?? defaultTargetPlatform);
    SingleActivator cmd(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, meta: apple, control: !apple, shift: shift);

    return <CanvasShortcutGroup>[
      CanvasShortcutGroup('Tools', inMenu: false, <CanvasShortcut>[
        for (final entry in ToolShortcuts.keys.entries)
          CanvasShortcut(
            ToolShortcuts.labels[entry.key]!,
            SingleActivator(entry.value),
            SelectToolIntent(entry.key),
          ),
      ]),
      CanvasShortcutGroup('Edit', <CanvasShortcut>[
        CanvasShortcut(
          'Copy',
          cmd(LogicalKeyboardKey.keyC),
          const CopySelectionIntent(),
        ),
        CanvasShortcut(
          'Cut',
          cmd(LogicalKeyboardKey.keyX),
          const CutSelectionIntent(),
        ),
        CanvasShortcut(
          'Paste',
          cmd(LogicalKeyboardKey.keyV),
          const PasteSceneIntent(),
        ),
        CanvasShortcut(
          'Duplicate',
          cmd(LogicalKeyboardKey.keyD),
          const DuplicateSelectionIntent(),
        ),
        CanvasShortcut(
          'Select all',
          cmd(LogicalKeyboardKey.keyA),
          const SelectAllElementsIntent(),
        ),
        CanvasShortcut(
          'Delete',
          const SingleActivator(LogicalKeyboardKey.delete),
          const DeleteSelectionIntent(),
        ),
        CanvasShortcut(
          'Delete',
          const SingleActivator(LogicalKeyboardKey.backspace),
          const DeleteSelectionIntent(),
        ),
        CanvasShortcut(
          'Deselect',
          const SingleActivator(LogicalKeyboardKey.escape),
          const ClearSelectionIntent(),
        ),
      ]),
      CanvasShortcutGroup('History', <CanvasShortcut>[
        CanvasShortcut(
          'Undo',
          cmd(LogicalKeyboardKey.keyZ),
          const UndoCanvasIntent(),
        ),
        CanvasShortcut(
          'Redo',
          cmd(LogicalKeyboardKey.keyZ, shift: true),
          const RedoCanvasIntent(),
        ),
        // Kept on every platform, not just Windows: it is what the canvas
        // answered to before this layer existed, and it costs nothing.
        CanvasShortcut(
          'Redo',
          const SingleActivator(LogicalKeyboardKey.keyY, control: true),
          const RedoCanvasIntent(),
        ),
      ]),
      CanvasShortcutGroup('Arrange', <CanvasShortcut>[
        CanvasShortcut(
          'Bring forward',
          cmd(LogicalKeyboardKey.bracketRight),
          const ReorderSelectionIntent(ZOrderShift.forward),
        ),
        CanvasShortcut(
          'Send backward',
          cmd(LogicalKeyboardKey.bracketLeft),
          const ReorderSelectionIntent(ZOrderShift.backward),
        ),
        CanvasShortcut(
          'Bring to front',
          cmd(LogicalKeyboardKey.bracketRight, shift: true),
          const ReorderSelectionIntent(ZOrderShift.front),
        ),
        CanvasShortcut(
          'Send to back',
          cmd(LogicalKeyboardKey.bracketLeft, shift: true),
          const ReorderSelectionIntent(ZOrderShift.back),
        ),
        CanvasShortcut(
          'Group',
          cmd(LogicalKeyboardKey.keyG),
          const GroupSelectionIntent(),
        ),
        CanvasShortcut(
          'Ungroup',
          cmd(LogicalKeyboardKey.keyG, shift: true),
          const UngroupSelectionIntent(),
        ),
      ]),
      // Every arrow shares one label so the reference sheet folds the four
      // of them into a single row (see `ShortcutLabel.merge`) instead of
      // spending eight lines saying the same thing four times.
      CanvasShortcutGroup('Move selection', inMenu: false, <CanvasShortcut>[
        for (final entry in _arrows.entries)
          CanvasShortcut(
            'Nudge',
            SingleActivator(entry.key),
            NudgeSelectionIntent(entry.value * nudgeStep),
          ),
        for (final entry in _arrows.entries)
          CanvasShortcut(
            'Nudge 10 px',
            SingleActivator(entry.key, shift: true),
            NudgeSelectionIntent(entry.value * nudgeStepCoarse),
          ),
      ]),
      CanvasShortcutGroup('Help', const <CanvasShortcut>[
        // A character activator, not Shift+/: which physical key produces
        // "?" depends on the layout, and only the character is stable.
        CanvasShortcut(
          'Keyboard shortcuts',
          CharacterActivator('?'),
          ShowShortcutsIntent(),
        ),
      ]),
    ];
  }

  /// What the modifier keys do during pointer gestures, and what the inline
  /// text editor answers to — behaviour that lives in the gesture handler
  /// and the editor rather than in [groups], and that the sheet would
  /// otherwise leave out. Alt-to-unsnap and Shift-to-lock-aspect are the
  /// two people never find on their own.
  ///
  /// Kept beside the bindings so the sheet stays one file's reading; the
  /// spellings follow [platform] the way `ShortcutLabel` spells chords.
  static List<CanvasModifierGroup> modifierGroups([TargetPlatform? platform]) {
    final apple = _isApple(platform ?? defaultTargetPlatform);
    final shift = apple ? '⇧' : 'Shift';
    final alt = apple ? '⌥' : 'Alt';
    final sep = apple ? ' ' : '+';

    return <CanvasModifierGroup>[
      CanvasModifierGroup('Pointer modifiers', <CanvasModifierHint>[
        CanvasModifierHint(
          'Add to / remove from selection',
          '$shift${sep}click',
        ),
        CanvasModifierHint(
          'Keep aspect ratio while resizing',
          '$shift${sep}drag',
        ),
        CanvasModifierHint('Disable snapping while dragging', '$alt${sep}drag'),
        const CanvasModifierHint('Edit text', 'Double-click'),
      ]),
      CanvasModifierGroup('While editing text', <CanvasModifierHint>[
        const CanvasModifierHint('Commit', 'Enter'),
        CanvasModifierHint('New line', '$shift${sep}Enter'),
        const CanvasModifierHint('Cancel edit', 'Esc'),
        const CanvasModifierHint('Cancel project rename', 'Esc'),
      ]),
    ];
  }

  /// The table flattened into the map `Shortcuts` wants.
  static Map<ShortcutActivator, Intent> bindings([TargetPlatform? platform]) {
    return <ShortcutActivator, Intent>{
      for (final group in groups(platform))
        for (final shortcut in group.shortcuts)
          shortcut.activator: shortcut.intent,
    };
  }

  /// The same table as the top-bar menu sees it: menu-worthy groups only,
  /// one entry per label.
  ///
  /// Deduplicating matters because several commands are bound twice —
  /// Delete answers both Del and Backspace, Redo both ⇧⌘Z and Ctrl+Y — and
  /// a menu listing each of them twice looks like two different commands.
  static List<CanvasShortcutGroup> menuGroups([TargetPlatform? platform]) {
    return [
      for (final group in groups(platform))
        if (group.inMenu)
          CanvasShortcutGroup(group.title, _firstPerLabel(group.shortcuts)),
    ];
  }

  static List<CanvasShortcut> _firstPerLabel(List<CanvasShortcut> shortcuts) {
    final seen = <String>{};
    return [
      for (final shortcut in shortcuts)
        if (seen.add(shortcut.label)) shortcut,
    ];
  }

  static final Map<LogicalKeyboardKey, Offset> _arrows = {
    LogicalKeyboardKey.arrowLeft: Offset(-1, 0),
    LogicalKeyboardKey.arrowRight: Offset(1, 0),
    LogicalKeyboardKey.arrowUp: Offset(0, -1),
    LogicalKeyboardKey.arrowDown: Offset(0, 1),
  };

  static bool _isApple(TargetPlatform platform) =>
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
}
