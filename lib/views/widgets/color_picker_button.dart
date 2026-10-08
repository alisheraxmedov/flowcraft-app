import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/toolbar/popover_button.dart';

/// A small colour chip that opens an HSV picker beside the inspector.
///
/// Gesture contract (the same one the inspector sliders follow): [onStart]
/// at pointer-down, [onChanged] for every colour along the drag, [onEnd] at
/// pointer-up. The caller arms/ends a drag session around them so the whole
/// gesture is a single undo entry.
class ColorPickerButton extends StatelessWidget {
  const ColorPickerButton({
    super.key,
    required this.tooltip,
    required this.color,
    required this.initial,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
    this.mixed = false,
    this.anchorKey,
  });

  /// "Pick stroke colour": tooltip and semantics label.
  final String tooltip;

  /// What the chip shows; `null` = no fill (drawn with a slash).
  final Color? color;

  /// Where the picker starts when opened.
  final Color initial;
  final bool mixed;

  /// The inspector island: the picker opens beside it, not over its fields.
  final GlobalKey? anchorKey;
  final VoidCallback onStart;
  final ValueChanged<Color> onChanged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return PopoverButton(
      tooltip: tooltip,
      activeColor: fc.accent,
      anchor: PopoverAnchor.side,
      anchorKey: anchorKey,
      size: 24,
      radius: 12,
      builder: (_, _) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: mixed ? fc.surface2 : color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fc.glassBorder),
        ),
        child: color == null && !mixed
            ? const FcIconGlyph(FcIcons.strokeNone, size: 20)
            : null,
      ),
      popoverBuilder: (_, _) => _PickerBody(
        initial: initial,
        onStart: onStart,
        onChanged: onChanged,
        onEnd: onEnd,
      ),
    );
  }
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({
    required this.initial,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  final Color initial;
  final VoidCallback onStart;
  final ValueChanged<Color> onChanged;
  final VoidCallback onEnd;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  static const _w = 200.0, _h = 140.0, _thumb = 16.0;

  /// Kept here, not re-derived from the element: HSV is lossy at s=0 / v=0,
  /// so a round trip through the picked colour would lose the hue mid-drag.
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    widget.onChanged(hsv.toColor());
  }

  /// A field, not a local: every [setState] rebuilds the closures below.
  bool _active = false;

  /// One pointer-down→up gesture over [size]; [update] gets the local point.
  Widget _surface(Size size, Widget child, void Function(Offset) update) {
    void end(_) {
      if (!_active) return;
      _active = false;
      widget.onEnd();
    }

    return Listener(
      onPointerDown: (e) {
        _active = true;
        widget.onStart();
        update(e.localPosition);
      },
      onPointerMove: (e) => _active ? update(e.localPosition) : null,
      onPointerUp: end,
      onPointerCancel: end,
      child: SizedBox.fromSize(size: size, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final hue = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final color = _hsv.toColor();
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final hairline = Border.all(color: fc.glassBorder);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _surface(
            const Size(_w, _h),
            Stack(
              key: const ValueKey('color_picker_sv'),
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: hairline,
                      gradient: LinearGradient(colors: [Colors.white, hue]),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _hsv.saturation * _w - 7,
                  top: (1 - _hsv.value) * _h - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            (p) => _set(
              _hsv
                  .withSaturation((p.dx / _w).clamp(0.0, 1.0))
                  .withValue(1 - (p.dy / _h).clamp(0.0, 1.0)),
            ),
          ),
          const SizedBox(height: 12),
          _surface(
            const Size(_w, _thumb),
            Stack(
              key: const ValueKey('color_picker_hue'),
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 2,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: hairline,
                      gradient: LinearGradient(
                        colors: [
                          for (var i = 0; i <= 6; i++)
                            HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _hsv.hue / 360 * (_w - _thumb),
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hue,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            (p) => _set(
              _hsv.withHue(
                ((p.dx - _thumb / 2) / (_w - _thumb)).clamp(0.0, 1.0) * 360,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: hairline,
                ),
              ),
              const SizedBox(width: 8),
              Text(hex, style: AppTypography.mono12.copyWith(color: fc.text)),
            ],
          ),
        ],
      ),
    );
  }
}
