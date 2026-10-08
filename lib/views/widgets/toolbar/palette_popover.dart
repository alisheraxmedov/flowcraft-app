import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

/// Default stroke / text palette (Excalidraw-ish). The inspector swaps the
/// first entry for the theme's ink — see `inkFor`.
const List<Color> defaultPalette = [
  Color(0xFF1E1E1E),
  Color(0xFFE03131),
  Color(0xFFD6336C),
  Color(0xFFAE3EC9),
  Color(0xFF7048E8),
  Color(0xFF1971C2),
  Color(0xFF0CA678),
  Color(0xFF74B816),
  Color(0xFFF59F00),
  Color(0xFFFFFFFF),
];

/// Default fill palette — same set with a "none" sentinel up front.
const List<Color?> defaultFillPalette = [
  null,
  Color(0xFFFFE3E3),
  Color(0xFFFCE4EC),
  Color(0xFFF3E5F5),
  Color(0xFFEDE7F6),
  Color(0xFFE3F2FD),
  Color(0xFFE0F2F1),
  Color(0xFFE6F4EA),
  Color(0xFFFFF8E1),
  Color(0xFFFFFFFF),
];

/// One tappable colour in the inspector's palette grid.
///
/// A real button rather than a bare `GestureDetector`: it names its colour
/// to a screen reader and on hover, takes keyboard focus, and shows a click
/// cursor. `null` is the fill palette's "none" entry.
///
/// Geometry is the mockup's: a 32px hit box with a 2px ring (accent when
/// [current], transparent otherwise) around a 22px dot (20px when ringed)
/// that carries an inset 1px grey outline.
class Swatch extends StatelessWidget {
  const Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.current,
    required this.onTap,
    this.dot,
  });

  /// The value this swatch stands for (`null` = "no fill").
  final Color? color;
  final String label;
  final bool current;
  final VoidCallback onTap;

  /// What to paint inside the circle when it differs from [color]: the first
  /// stroke swatch's value is the theme's ink, but it is drawn in the softer
  /// `swatchInk` token.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final fill = dot ?? color;
    final d = current ? 20.0 : 22.0;
    // White needs a firmer outline than the rest to read on a light island.
    final ring = fill == const Color(0xFFFFFFFF) ? 0.45 : 0.35;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: current,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2,
                color: current ? t.accent : Colors.transparent,
              ),
            ),
            child: Container(
              width: d,
              height: d,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color == null ? t.raised : fill,
                border: Border.all(
                  color: const Color(0xFF808080).withValues(alpha: ring),
                ),
              ),
              child: color == null
                  // The mockup's 22px slash is allowed to overflow the 20px
                  // ringed dot, so it is not shrunk to fit.
                  ? OverflowBox(
                      maxWidth: 22,
                      maxHeight: 22,
                      child: FcIconGlyph(FcIcons.strokeNone, size: 22),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
