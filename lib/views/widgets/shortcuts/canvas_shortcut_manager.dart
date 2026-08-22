import 'package:flutter/widgets.dart';

/// A [ShortcutManager] that stands aside while the user is typing.
///
/// This exists because of how Flutter routes keys. A character key is
/// delivered to the focused node and then walks *up* the focus tree; an
/// [EditableText] inserts text through the platform input connection, not
/// through that walk, so it neither consumes the event nor stops it. A plain
/// `R` typed into the properties panel therefore reaches every ancestor
/// `Shortcuts` — and this layer, being nearer the field than
/// `WidgetsApp`'s own text-editing shortcuts, would answer `⌘C`, `⌫` and the
/// arrow keys *instead of* the field. The symptom is a text box that eats
/// its own Backspace and a tool that changes while you name a project, with
/// nothing in the stack trace to point at.
///
/// Returning [KeyEventResult.ignored] (rather than filtering the map) hands
/// the whole event back to the walk, so `DefaultTextEditingShortcuts` above
/// still gets its turn.
class CanvasShortcutManager extends ShortcutManager {
  CanvasShortcutManager({
    super.shortcuts = const <ShortcutActivator, Intent>{},
  });

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (isTypingContext(FocusManager.instance.primaryFocus)) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }

  /// Whether [focus] sits inside a live text-editing surface: the inline
  /// canvas text editor, a properties-panel field, or the project rename
  /// box.
  ///
  /// Read-only editables are excluded on purpose — a focused `SelectableText`
  /// is not somewhere keystrokes go, so it must not disarm the canvas.
  static bool isTypingContext(FocusNode? focus) {
    final context = focus?.context;
    if (context == null) return false;
    // `EditableText` is the one widget every text surface in Flutter is
    // built on, and it is always an ancestor of the node it focuses (it
    // builds the `Focus` that owns it), so this catches `TextField`,
    // `EditableText` used bare, and anything else layered on top.
    final editable = context.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && !editable.readOnly;
  }
}
