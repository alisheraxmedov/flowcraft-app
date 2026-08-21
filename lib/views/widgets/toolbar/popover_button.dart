import 'package:flutter/material.dart';

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

  late final PopoverController _ctrl = PopoverController(
    () {
      if (!_portal.isShowing) _portal.show();
    },
    () {
      if (_portal.isShowing) _portal.hide();
    },
  );

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      _portal.show();
    }
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
                  behavior: HitTestBehavior.translucent,
                  onTap: _ctrl.hide,
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
                    child: Material(
                    elevation: 6,
                    borderRadius: AppRadius.mdRadius,
                    clipBehavior: Clip.antiAlias,
                    child: widget.popoverBuilder(context, _ctrl.hide),
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
