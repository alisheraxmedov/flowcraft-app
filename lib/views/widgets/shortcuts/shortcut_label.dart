import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show CharacterActivator, ShortcutActivator, SingleActivator;

import 'package:flowcraft/views/widgets/shortcuts/canvas_shortcut_table.dart';

/// Renders a [ShortcutActivator] the way the user's platform writes it.
///
/// Apple keyboards are labelled with glyphs and no separators (`⇧⌘Z`);
/// everywhere else the convention is spelled-out words joined by `+`
/// (`Ctrl+Shift+Z`). Printing one style on both platforms is the kind of
/// detail that makes an app feel ported rather than built.
class ShortcutLabel {
  ShortcutLabel._();

  /// Human text for a single activator, e.g. `⌘C` / `Ctrl+C`.
  static String of(ShortcutActivator activator, TargetPlatform platform) {
    final apple =
        platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    if (activator is CharacterActivator) return activator.character;
    if (activator is! SingleActivator) return activator.debugDescribeKeys();

    final parts = <String>[
      if (activator.control) apple ? '⌃' : 'Ctrl',
      if (activator.alt) apple ? '⌥' : 'Alt',
      if (activator.shift) apple ? '⇧' : 'Shift',
      if (activator.meta) apple ? '⌘' : 'Win',
      _trigger(activator.trigger),
    ];
    return parts.join(apple ? '' : '+');
  }

  /// Collapses shortcuts that share a label into one reference-sheet row —
  /// "Delete" is both Del and Backspace, "Nudge" is all four arrows, and
  /// listing them as separate rows reads as four different features.
  static List<({String label, String keys})> merge(
    List<CanvasShortcut> shortcuts,
    TargetPlatform platform,
  ) {
    final byLabel = <String, List<String>>{};
    for (final shortcut in shortcuts) {
      (byLabel[shortcut.label] ??= <String>[]).add(
        of(shortcut.activator, platform),
      );
    }
    return [
      for (final entry in byLabel.entries)
        (label: entry.key, keys: entry.value.join(' / ')),
    ];
  }

  /// Key names Flutter spells out in full but keyboards print as a symbol.
  static String _trigger(LogicalKeyboardKey key) =>
      _glyphs[key] ?? key.keyLabel;

  static final Map<LogicalKeyboardKey, String> _glyphs = {
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.escape: 'Esc',
    LogicalKeyboardKey.delete: 'Del',
    LogicalKeyboardKey.backspace: '⌫',
  };
}
