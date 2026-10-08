import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';

/// A pill of mutually exclusive segments; the selected one lifts onto a
/// raised chip. Stateless: the caller owns [value].
class FcSegmented<T> extends StatelessWidget {
  const FcSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 26,
    this.gap = 0,
    this.segmentPadding = EdgeInsets.zero,
    this.inactiveColor,
    this.fontSize,
    this.activeWeight,
  });

  /// Segment height (26 in the inspector, 34 in the Connect dialog).
  final double height;

  /// Space between segments.
  final double gap;
  final EdgeInsetsGeometry segmentPadding;

  /// Unselected label colour; defaults to `muted`.
  final Color? inactiveColor;

  /// Label size / selected-label weight; default to the theme's labelMedium.
  final double? fontSize;
  final FontWeight? activeWeight;

  final T value;

  /// Value -> label, in display order.
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        spacing: gap,
        children: [
          for (final e in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.key),
                  child: Container(
                    height: height,
                    padding: segmentPadding,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? t.raised : null,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: e.key == value ? t.raisedShadow : null,
                    ),
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        fontSize: fontSize,
                        fontWeight: e.key == value ? activeWeight : null,
                        color: e.key == value
                            ? t.accentText
                            : (inactiveColor ?? t.muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
