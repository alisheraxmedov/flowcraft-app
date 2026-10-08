import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/views/widgets/shortcuts/tool_shortcuts.dart';

/// A single tool-picker button in the rich sketch toolbar — an icon that
/// highlights when [selected] and invokes [onTap] to switch tools.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.tool,
    required this.selected,
    required this.activeColor,
    required this.onActiveColor,
    required this.iconColor,
    required this.onTap,
  });

  final SketchTool tool;
  final bool selected;

  /// Background color when [selected].
  final Color activeColor;

  /// Icon color when [selected] (drawn against [activeColor]).
  final Color onActiveColor;

  /// Icon color when not selected.
  final Color iconColor;
  final VoidCallback onTap;

  static const double _size = 40;
  static const Duration _duration = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      // The user-facing name plus its key — not `tool.name`, which printed
      // the Dart identifier ("freedraw", "sticky") and taught nobody `P`.
      message: ToolShortcuts.tooltip(tool),
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        hoverColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          width: _size,
          height: _size,
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: selected ? 1.1 : 1.0,
            duration: _duration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: _duration,
              width: _size - 4,
              height: _size - 4,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                borderRadius: AppRadius.mdRadius,
              ),
              child: Center(
                child: ToolGlyph(
                  tool: tool,
                  color: selected ? onActiveColor : iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Material-icon glyph representing a single [SketchTool].
class ToolGlyph extends StatelessWidget {
  const ToolGlyph({super.key, required this.tool, required this.color});

  final SketchTool tool;
  final Color color;

  IconData get _icon {
    switch (tool) {
      case SketchTool.select:
        return Icons.near_me_outlined;
      case SketchTool.hand:
        return Icons.pan_tool_outlined;
      case SketchTool.rectangle:
        return Icons.crop_square_rounded;
      case SketchTool.ellipse:
        return Icons.circle_outlined;
      case SketchTool.diamond:
        return Icons.diamond_rounded;
      case SketchTool.triangle:
        return Icons.change_history_rounded;
      case SketchTool.sticky:
        return Icons.sticky_note_2_outlined;
      case SketchTool.line:
        return Icons.show_chart_rounded;
      case SketchTool.arrow:
        return Icons.arrow_forward_rounded;
      case SketchTool.freedraw:
        return Icons.draw_outlined;
      case SketchTool.text:
        return Icons.text_fields_rounded;
      case SketchTool.frame:
        return Icons.crop_free_rounded;
      case SketchTool.icon:
        return Icons.interests_outlined;
      case SketchTool.eraser:
        // Material's own glyph set has no eraser. The Symbols font is 32 MB
        // in the pub cache, but Flutter's icon tree-shaker keeps only the
        // glyphs a `const IconData` references — verified in the release
        // bundle — so this costs one glyph, not the font. Keep it const.
        return Symbols.ink_eraser_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Icon(_icon, size: 18, color: color);
}
