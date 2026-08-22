import 'package:flutter/material.dart';

import 'package:flowcraft/models/sketch_style.dart';

/// Popover content: a labeled slider for a numeric style value (stroke
/// width, roughness, ...).
class SliderPopover extends StatefulWidget {
  const SliderPopover({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  /// Drag-lifecycle hooks. The toolbar brackets the drag with them so a
  /// continuous slide over a selection collapses into one undo entry
  /// instead of one per tick.
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<SliderPopover> createState() => _SliderPopoverState();
}

class _SliderPopoverState extends State<SliderPopover> {
  late double _value = widget.value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(widget.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(widget.format(_value),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          Slider(
            value: _value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
            onChangeStart: widget.onChangeStart,
            onChangeEnd: widget.onChangeEnd,
          ),
        ],
      ),
    );
  }
}

/// Popover content: a row of [ChoiceChip]s for picking one value out of
/// an enum-like option list (stroke style, fill style, ...).
class ChoicePopover<T> extends StatelessWidget {
  const ChoicePopover({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onPick,
  });

  final String label;
  final List<T> options;

  /// Chip to mark as current, or `null` to mark none — which is what the
  /// toolbar passes when a multi-selection disagrees about this field.
  final T? selected;

  final String Function(T) labelOf;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final opt in options)
                ChoiceChip(
                  label: Text(labelOf(opt)),
                  selected: opt == selected,
                  onSelected: (_) => onPick(opt),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [PopoverButton] anchor glyph previewing the current stroke width as a
/// short line segment.
class StrokeWidthGlyph extends StatelessWidget {
  const StrokeWidthGlyph({super.key, required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 18,
      child: CustomPaint(
        painter: _LineWeightPainter(color: color, width: width),
      ),
    );
  }
}

class _LineWeightPainter extends CustomPainter {
  _LineWeightPainter({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width.clamp(1.0, 8.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_LineWeightPainter old) =>
      color != old.color || width != old.width;
}

/// [PopoverButton] anchor glyph representing the current [StrokeStyle].
class StrokeStyleGlyph extends StatelessWidget {
  const StrokeStyleGlyph({super.key, required this.color, required this.style});

  final Color color;
  final StrokeStyle style;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (style) {
      case StrokeStyle.solid:
        icon = Icons.horizontal_rule_rounded;
        break;
      case StrokeStyle.dashed:
        icon = Icons.linear_scale_rounded;
        break;
      case StrokeStyle.dotted:
        icon = Icons.more_horiz_rounded;
        break;
    }
    return Icon(icon, size: 18, color: color);
  }
}
