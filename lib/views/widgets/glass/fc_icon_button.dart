import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';

/// Square icon button for the glass chrome: surface2 on hover, a raised
/// accent-text chip while [pressed] (toggled on), 35% opacity when disabled.
class FcIconButton extends StatefulWidget {
  const FcIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.pressed = false,
    this.size = 36,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool pressed;

  /// Hit box side. 36 -> radius 10, 40 -> radius 12 (per the mockup).
  final double size;
  final double iconSize;

  @override
  State<FcIconButton> createState() => _FcIconButtonState();
}

class _FcIconButtonState extends State<FcIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final enabled = widget.onPressed != null;
    final on = widget.pressed;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: on,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on
                      ? t.raised
                      : (_hover && enabled ? t.surface2 : null),
                  borderRadius: BorderRadius.circular(
                    widget.size >= 40 ? AppRadius.row : AppRadius.button,
                  ),
                  boxShadow: on ? t.raisedShadow : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: on ? t.accentText : t.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
