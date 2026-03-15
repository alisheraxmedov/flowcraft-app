import 'package:flutter/widgets.dart';

/// Displays an optional text label at the midpoint of an edge.
class EdgeLabelWidget extends StatelessWidget {
  /// Creates an [EdgeLabelWidget].
  const EdgeLabelWidget({
    super.key,
    required this.label,
    required this.position,
    this.style,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  /// The label text to display.
  final String label;

  /// The screen-space position of the label.
  final Offset position;

  /// Optional text style.
  final TextStyle? style;

  /// Background color behind the label.
  final Color backgroundColor;

  /// Padding around the label text.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: style ??
                const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF333333),
                ),
          ),
        ),
      ),
    );
  }
}
