import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';

/// Where a [PopoverButton]'s popover opens relative to its anchor.
enum PopoverAnchor {
  /// Below, left edges aligned.
  below,

  /// Below, right edges aligned (anchor sits at the right of a bar).
  belowEnd,

  /// Beside, to the anchor's right.
  side,
}

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
    this.anchor,
    this.size = 32,
    this.radius = AppRadius.menu,
    this.anchorKey,
  });

  final Widget Function(BuildContext, PopoverController) builder;
  final Widget Function(BuildContext, VoidCallback close) popoverBuilder;
  final String tooltip;
  final Color activeColor;
  final bool vertical;

  /// Placement override; null keeps the legacy [vertical] behaviour
  /// (side when vertical, below otherwise).
  final PopoverAnchor? anchor;

  /// Side of the square hit box; the tool rail's icon picker passes 40 to
  /// line up with its [ToolButton] neighbours.
  final double size;

  /// Corner radius of the popover surface: 14 (menu) by default, 18 for the
  /// Projects popover, 12 for a row's "…" menu, per the mockup.
  final double radius;

  /// Positions the popover against this widget (e.g. the whole island the
  /// button sits in) instead of the button itself. The Projects popover
  /// uses it: the mockup left-aligns it with the island, 8px below it. With
  /// [PopoverAnchor.side] the popover opens 8px right of that widget, top
  /// aligned with the button (the inspector's colour picker).
  final GlobalKey? anchorKey;

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
    // overlayChildLayoutBuilder, not a CompositedTransformFollower: a follower
    // above a popover's own Tooltips trips their layout-time paint transform.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final anchor =
            widget.anchor ??
            (widget.vertical ? PopoverAnchor.side : PopoverAnchor.below);
        final anchorBox = widget.anchorKey?.currentContext?.findRenderObject();
        final Rect? target;
        if (anchorBox == null) {
          target = widget.anchorKey != null
              ? null
              : MatrixUtils.transformRect(
                  info.childPaintTransform,
                  Offset.zero & info.childSize,
                );
        } else {
          final overlay = Overlay.of(context).context.findRenderObject();
          target =
              (anchorBox as RenderBox).localToGlobal(
                Offset.zero,
                ancestor: overlay,
              ) &
              anchorBox.size;
        }
        final gap = widget.anchorKey == null ? 6.0 : 8.0;
        // Side + anchorKey: beside the anchor widget (the inspector island),
        // top-aligned with this button's row rather than centred on it.
        final beside = anchor == PopoverAnchor.side && widget.anchorKey != null;
        final button = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
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
            // No anchor, no popover: never paint at 0,0.
            if (target != null)
              Positioned(
                left: anchor == PopoverAnchor.belowEnd
                    ? null
                    : anchor == PopoverAnchor.side
                    ? target.right + (beside ? 8 : 6)
                    : target.left,
                right: anchor == PopoverAnchor.belowEnd
                    ? info.overlaySize.width - target.right
                    : null,
                top: beside
                    ? button.top - 4
                    : anchor == PopoverAnchor.side
                    ? target.center.dy
                    : target.bottom + gap,
                child: FractionalTranslation(
                  translation: anchor == PopoverAnchor.side && !beside
                      ? const Offset(0, -0.5)
                      : Offset.zero,
                  child: Focus(
                    focusNode: _focus,
                    onKeyEvent: _onKey,
                    // Material kept inside the island: popover content uses
                    // InkWell/ListTile, which need a Material ancestor.
                    child: GlassIsland(
                      strong: true,
                      radius: widget.radius,
                      child: Material(
                        type: MaterialType.transparency,
                        child: widget.popoverBuilder(context, _hide),
                      ),
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
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: _toggle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            child: widget.builder(context, _ctrl),
          ),
        ),
      ),
    );
  }
}
