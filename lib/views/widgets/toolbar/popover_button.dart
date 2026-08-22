import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

import 'package:flowcraft/core/theme/app_radius.dart';

/// Generic anchor button that opens a floating popover on tap.
///
/// Knows nothing about what it hosts — [builder] renders the anchor's
/// glyph and [popoverBuilder] renders the popover content, given a
/// `close` callback to dismiss it. Reusable across every toolbar button
/// that needs a floating panel (color swatches, sliders, choice chips).
class PopoverButton extends StatefulWidget {
  const PopoverButton({
    super.key,
    required this.builder,
    required this.popoverBuilder,
    required this.tooltip,
    required this.activeColor,
    this.vertical = false,
  });

  final Widget Function(BuildContext, PopoverController) builder;
  final Widget Function(BuildContext, VoidCallback close) popoverBuilder;
  final String tooltip;
  final Color activeColor;
  final bool vertical;

  @override
  State<PopoverButton> createState() => _PopoverButtonState();
}

/// Handle passed to [PopoverButton.builder] to imperatively show/hide the
/// popover — most anchors don't need it (tapping already toggles it), but
/// it's available for anchors that want programmatic control.
class PopoverController {
  PopoverController(this._show, this._hide);
  final VoidCallback _show;
  final VoidCallback _hide;
  void show() => _show();
  void hide() => _hide();
}

class _PopoverButtonState extends State<PopoverButton> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// Holds focus while the popover is open so Escape reaches it — an open
  /// popover used to leave focus on the canvas, where Escape meant
  /// "deselect" and the popover stayed put. Requested explicitly rather
  /// than via `autofocus`, which only fires when nothing in the scope is
  /// focused, and the canvas always is. Detaching it on hide hands focus
  /// back to the enclosing scope, which is the shortcut layer's own.
  final FocusNode _focus = FocusNode(debugLabel: 'popover');

  late final PopoverController _ctrl = PopoverController(_show, _hide);

  void _show() {
    if (_portal.isShowing) return;
    _portal.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _focus.requestFocus();
    });
  }

  void _hide() {
    if (_portal.isShowing) _portal.hide();
  }

  void _toggle() => _portal.isShowing ? _hide() : _show();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  // Opaque: the click that dismisses a popover is spent on
                  // dismissing it. Translucent let it fall through to the
                  // canvas and start a stroke with whichever tool was live.
                  behavior: HitTestBehavior.opaque,
                  onTap: _hide,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: widget.vertical
                      ? Alignment.centerRight
                      : Alignment.bottomLeft,
                  followerAnchor: widget.vertical
                      ? Alignment.centerLeft
                      : Alignment.topLeft,
                  offset: widget.vertical
                      ? const Offset(6, 0)
                      : const Offset(0, 6),
                  child: Focus(
                    focusNode: _focus,
                    onKeyEvent: _onKey,
                    child: Material(
                      elevation: 6,
                      borderRadius: AppRadius.mdRadius,
                      clipBehavior: Clip.antiAlias,
                      child: widget.popoverBuilder(context, _hide),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: Tooltip(
          message: widget.tooltip,
          child: InkWell(
            borderRadius: AppRadius.smRadius,
            onTap: _toggle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: widget.builder(context, _ctrl),
            ),
          ),
        ),
      ),
    );
  }
}
