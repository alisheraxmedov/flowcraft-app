import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/shortcuts/tool_shortcuts.dart';

/// Each tool's chrome glyph (Lucide, rendered 1:1 from the mockups by
/// [FcIconGlyph]).
const Map<SketchTool, FcIcon> toolIcons = {
  SketchTool.select: FcIcons.mousePointer2,
  SketchTool.hand: FcIcons.hand,
  SketchTool.rectangle: FcIcons.square,
  SketchTool.ellipse: FcIcons.circle,
  SketchTool.diamond: FcIcons.diamond,
  SketchTool.triangle: FcIcons.triangle,
  SketchTool.sticky: FcIcons.stickyNote,
  SketchTool.line: FcIcons.lineDiagonal,
  SketchTool.arrow: FcIcons.arrowUpRight,
  SketchTool.freedraw: FcIcons.pencil,
  SketchTool.text: FcIcons.type,
  SketchTool.frame: FcIcons.frame,
  SketchTool.icon: FcIcons.shapes,
  SketchTool.eraser: FcIcons.eraser,
};

/// A single tool-picker button of the tool island: 40x40, radius 12, a
/// raised accent-text chip while [selected], surface2 on hover.
///
/// Its tooltip is the mockup's: the tool's name plus its key in a mono chip.
/// That is a `richMessage`, so `find.byTooltip` sees the plain text
/// "Name￼" (the chip is a placeholder) rather than "Name · K".
class ToolButton extends StatefulWidget {
  const ToolButton({
    super.key,
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final SketchTool tool;
  final bool selected;
  final VoidCallback onTap;

  static const double size = 40;
  static const Duration _duration = Duration(milliseconds: 120);

  @override
  State<ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<ToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final on = widget.selected;
    final name = ToolShortcuts.labels[widget.tool]!;
    final key = ToolShortcuts.keys[widget.tool]!.keyLabel;
    return Semantics(
      button: true,
      selected: on,
      label: '$name ($key)',
      excludeSemantics: true,
      child: Tooltip(
        excludeFromSemantics: true,
        // 10px under the 40px button, exactly as the mockup places it.
        verticalOffset: ToolButton.size / 2 + 10,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: t.tooltipBg,
          borderRadius: BorderRadius.circular(AppRadius.input),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        richMessage: TextSpan(
          children: [
            TextSpan(text: name),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _KeyChip(label: key, color: t.tooltipFg),
              ),
            ),
          ],
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: ToolButton._duration,
              width: ToolButton.size,
              height: ToolButton.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on
                    ? t.raised
                    : (_hover ? t.surface2 : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.row),
                boxShadow: on ? t.raisedShadow : null,
              ),
              child: FcIconGlyph(
                toolIcons[widget.tool]!,
                size: 20,
                color: on ? t.accentText : t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tooltip's key cap: Geist Mono 11/500, min 18x18, radius 5, 18% white.
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        borderRadius: BorderRadius.circular(5),
      ),
      // Shrink-wrapped centring: `Container(alignment:)` would expand to the
      // full width the tooltip's rich text offers a WidgetSpan.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Geist Mono',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1,
            color: color,
          ),
        ),
      ),
    );
  }
}
