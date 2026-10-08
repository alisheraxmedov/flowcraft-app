import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';

/// Panel look of the Edit and Export menus, per the mockup: 260 wide, radius
/// 14, glass-strong with a real backdrop blur, 1px border, the island shadow.
///
/// The Material panel itself is transparent and unpadded: the glass (fill,
/// blur, border, radius, padding) lives in [FcMenuPanel], which every menu
/// passes as its single child. A [BackdropFilter] cannot sit behind a
/// `MenuStyle` background, but it can sit inside the panel.
///
/// ponytail: the panel scroll view clips the island's own shadow, so the
/// shadow is Material elevation (drawn outside the clip) -- close to, not
/// identical with, the mockup's `0 10px 30px / 0 1px 3px`. Exact parity would
/// need the menu hosted in an OverlayPortal instead of `MenuAnchor`.
MenuStyle fcMenuStyle(BuildContext context) {
  return MenuStyle(
    minimumSize: const WidgetStatePropertyAll(Size(260, 0)),
    maximumSize: const WidgetStatePropertyAll(Size(260, double.infinity)),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    elevation: const WidgetStatePropertyAll(6),
    shadowColor: WidgetStatePropertyAll(
      context.fc.shadow.first.color.withValues(alpha: 0.5),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.menu),
      ),
    ),
  );
}

/// The glass card inside a menu's transparent Material panel: [children]
/// stacked in a blurred [GlassIsland] with the mockup's 6px inner padding.
/// Pass it as the only entry of `menuChildren`.
class FcMenuPanel extends StatelessWidget {
  const FcMenuPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassIsland(
      strong: true,
      radius: AppRadius.menu,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
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
      // 260 panel - 2x1 border - 2x6 padding - 2x12 button padding.
      child: SizedBox(
        width: 222,
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
      menuChildren: [FcMenuPanel(children: children)],
      // The default arrow_right is a Material glyph; chevronDown turned a
      // quarter-turn is the mockup's chevron, pointing right.
      // A null submenuIcon falls back to the default, so the chevron goes in
      // that slot rather than trailingIcon (which sits beside the default).
      submenuIcon: const WidgetStatePropertyAll<Widget?>(
        RotatedBox(
          quarterTurns: 3,
          child: FcIconGlyph(FcIcons.chevronDown, size: 16),
        ),
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
