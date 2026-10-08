import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

/// Panel look of the Edit and Export menus, per the mockup: 260 wide, radius
/// 14, 1px glass border, the island shadow. The fill and 6px padding come
/// from `menuTheme` (opaque blended glass — a `MenuAnchor` can't host a
/// backdrop blur).
MenuStyle fcMenuStyle(BuildContext context) {
  final t = context.fc;
  return MenuStyle(
    minimumSize: const WidgetStatePropertyAll(Size(260, 0)),
    maximumSize: const WidgetStatePropertyAll(Size(260, double.infinity)),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.menu),
        side: BorderSide(color: t.glassBorder),
      ),
    ),
  );
}

/// One menu row: [label] (and optional leading [icon] / trailing [hint]).
///
/// Hover is surface2; keyboard focus is the accent fill (danger fill for a
/// [danger] row) — the mockup's highlighted-row state. Colours flow through
/// the button style's foreground/icon colours, and the hint reads the icon
/// colour, so one state change recolours all three.
class FcMenuItem extends StatelessWidget {
  const FcMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.hint,
    this.danger = false,
    this.height = 30,
  });

  final String label;
  final VoidCallback? onPressed;
  final FcIcon? icon;

  /// Right-aligned shortcut text, Geist Mono 12 muted.
  final String? hint;
  final bool danger;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return MenuItemButton(
      onPressed: onPressed,
      style: _rowStyle(t, danger: danger, height: height),
      // 260 panel - 2x6 padding - 2x12 button padding.
      child: SizedBox(
        width: 224,
        child: Row(
          children: [
            if (icon != null) ...[
              FcIconGlyph(icon!, size: 16),
              const SizedBox(width: 10),
            ],
            // The label is laid out first at its natural width; only the
            // hint may shrink (ellipsis) when a row is too tight. The
            // FittedBox is a backstop that scales a label that still cannot
            // fit instead of clipping it (real faces never reach it).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, softWrap: false),
            ),
            if (hint != null)
              Expanded(
                child: Builder(
                  builder: (context) => Text(
                    hint!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono12.copyWith(
                      color: IconTheme.of(context).color,
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Shared row look of [FcMenuItem] and [FcSubmenu].
ButtonStyle _rowStyle(
  FcTokens t, {
  required bool danger,
  required double height,
}) {
  return ButtonStyle(
    // Exact mockup row height: no platform density shrink, no 48px tap pad.
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: WidgetStatePropertyAll(Size(0, height)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused)
          ? (danger ? t.danger : t.accent)
          : s.contains(WidgetState.hovered)
          ? t.surface2
          : Colors.transparent,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) {
        return t.text.withValues(alpha: 0.4);
      }
      if (s.contains(WidgetState.focused)) {
        return danger ? t.onDanger : t.onAccent;
      }
      return danger ? t.danger : t.text;
    }),
    iconColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) {
        return t.muted.withValues(alpha: 0.5);
      }
      return s.contains(WidgetState.focused)
          ? (danger ? t.onDanger : t.onAccent)
          : t.muted;
    }),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: AppTypography.geistFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

/// A row that opens a nested glass menu of [children], styled as an
/// [FcMenuItem] with a trailing chevron.
class FcSubmenu extends StatelessWidget {
  const FcSubmenu({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      style: _rowStyle(context.fc, danger: false, height: 30),
      menuStyle: fcMenuStyle(context),
      menuChildren: children,
      // The default arrow_right is a Material glyph; chevronDown turned a
      // quarter-turn is the mockup's chevron, pointing right.
      trailingIcon: RotatedBox(
        quarterTurns: 3,
        child: FcIconGlyph(FcIcons.chevronDown, size: 16),
      ),
      child: Text(label),
    );
  }
}

/// Uppercase group caption: 11/600, +0.05em, muted, padding 8 12 4.
class FcMenuHeader extends StatelessWidget {
  const FcMenuHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.geistFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.55,
          color: context.fc.muted,
        ),
      ),
    );
  }
}

/// 1px rule with 4px / 8px margins between groups.
class FcMenuDivider extends StatelessWidget {
  const FcMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    color: context.fc.glassBorder,
  );
}
