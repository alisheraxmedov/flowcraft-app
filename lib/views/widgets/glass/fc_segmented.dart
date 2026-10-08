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
  });

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
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? t.raised : null,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: e.key == value ? t.raisedShadow : null,
                    ),
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: e.key == value ? t.accentText : t.muted,
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
