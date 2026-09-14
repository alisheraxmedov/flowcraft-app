import 'package:flutter/material.dart';

import 'style_popovers.dart' show popoverHeadingStyle;

/// `#RRGGBB`, the way the properties panel's hex field spells a colour.
String _hexOf(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Popover content: a swatch grid for picking a stroke [Color].
class PalettePopover extends StatelessWidget {
  const PalettePopover({
    super.key,
    required this.palette,
    required this.selected,
    required this.onPick,
  });

  final List<Color> palette;

  /// Swatch to ring as current, or `null` to ring none — which is what the
  /// toolbar passes when a multi-selection disagrees about this colour.
  final Color? selected;

  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Color', style: popoverHeadingStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in palette)
                Swatch(
                  color: c,
                  label: _hexOf(c),
                  current: selected == c,
                  onTap: () => onPick(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Popover content: a swatch grid for picking a fill [Color], with a
/// "none" sentinel entry (`null`) rendered as a slashed circle.
class FillPalettePopover extends StatelessWidget {
  const FillPalettePopover({
    super.key,
    required this.palette,
    required this.selected,
    required this.onPick,
    this.mixed = false,
  });

  final List<Color?> palette;
  final Color? selected;
  final ValueChanged<Color?> onPick;

  /// When true no swatch is ringed as current. `selected` can't express that
  /// here the way it can in [PalettePopover] — `null` is a real fill value
  /// ("none"), so "mixed" needs its own flag.
  final bool mixed;

  @override
  Widget build(BuildContext context) {
    bool isCurrent(Color? c) => !mixed && selected == c;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Fill', style: popoverHeadingStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in palette)
                Swatch(
                  color: c,
                  label: c == null ? 'No fill' : _hexOf(c),
                  current: isCurrent(c),
                  onTap: () => onPick(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable colour in a palette grid.
///
/// A real button rather than a bare `GestureDetector`: it names its colour
/// to a screen reader and on hover, takes keyboard focus, and shows a click
/// cursor — a 24-px circle that does none of those is a guess, not a
/// control. `null` is the fill palette's "none" entry.
class Swatch extends StatelessWidget {
  const Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.current,
    required this.onTap,
  });

  final Color? color;
  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                width: current ? 2.5 : 1.0,
                color: current ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            child: color == null
                ? Icon(
                    Icons.do_not_disturb_alt,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Small circular swatch used as a [PopoverButton] anchor glyph, showing
/// the currently selected stroke/fill color.
class SwatchCircle extends StatelessWidget {
  const SwatchCircle({
    super.key,
    required this.color,
    required this.border,
    this.showNone = false,
  });

  final Color? color;
  final Color border;
  final bool showNone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color ?? Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
      ),
      child: showNone
          ? Icon(
              Icons.do_not_disturb_alt,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}
