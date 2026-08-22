import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Color', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected == c ? 2.5 : 1.0,
                        color: selected == c
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    bool isCurrent(Color? c) => !mixed && selected == c;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Fill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c ?? Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: isCurrent(c) ? 2.5 : 1.0,
                        color: isCurrent(c)
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                    child: c == null
                        ? Icon(Icons.do_not_disturb_alt,
                            size: 14, color: colorScheme.onSurfaceVariant)
                        : null,
                  ),
                ),
            ],
          ),
        ],
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
          ? Icon(Icons.do_not_disturb_alt,
              size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
    );
  }
}
