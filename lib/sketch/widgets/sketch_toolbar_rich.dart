import 'package:flutter/material.dart';

import 'package:flowcraft/sketch/models/sketch_style.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/state/sketch_controller.dart';

/// Full-featured Excalidraw-style toolbar.
///
/// Single horizontal bar that exposes:
///
///  * Tool picker (select, hand, rectangle, ellipse, diamond, line,
///    arrow, freedraw, text, eraser).
///  * Stroke colour + fill colour swatch buttons → palette popover.
///  * Stroke width, roughness, stroke style, fill style → slider /
///    chip popovers.
///  * Undo / redo / clear inline.
///
/// Unlike [SketchToolbar], this widget depends on Flutter Material for
/// the popover anchors (`MenuAnchor`). Use it inside a [MaterialApp]
/// or any Material-aware host.
class SketchToolbarRich extends StatefulWidget {
  const SketchToolbarRich({
    super.key,
    required this.controller,
    this.palette = defaultPalette,
    this.fillPalette = defaultFillPalette,
    this.backgroundColor,
    this.activeColor = const Color(0xFF2196F3),
    this.iconColor = const Color(0xFF424242),
    this.orientation = Axis.horizontal,
    this.tools = const [
      SketchTool.select,
      SketchTool.hand,
      SketchTool.rectangle,
      SketchTool.ellipse,
      SketchTool.diamond,
      SketchTool.triangle,
      SketchTool.line,
      SketchTool.arrow,
      SketchTool.freedraw,
      SketchTool.text,
      SketchTool.sticky,
      SketchTool.eraser,
    ],
  });

  final SketchController controller;
  final List<Color> palette;
  final List<Color?> fillPalette;
  final Color? backgroundColor;
  final Color activeColor;
  final Color iconColor;

  /// Layout direction. Use [Axis.vertical] for a left/right side panel
  /// (like Paint); popovers open to the side in that mode.
  final Axis orientation;

  final List<SketchTool> tools;

  /// Default stroke / text palette (Excalidraw-ish).
  static const List<Color> defaultPalette = [
    Color(0xFF1E1E1E),
    Color(0xFFE03131),
    Color(0xFFD6336C),
    Color(0xFFAE3EC9),
    Color(0xFF7048E8),
    Color(0xFF1971C2),
    Color(0xFF0CA678),
    Color(0xFF74B816),
    Color(0xFFF59F00),
    Color(0xFFFFFFFF),
  ];

  /// Default fill palette — same set with a "none" sentinel up front.
  static const List<Color?> defaultFillPalette = [
    null,
    Color(0xFFFFE3E3),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFEDE7F6),
    Color(0xFFE3F2FD),
    Color(0xFFE0F2F1),
    Color(0xFFE6F4EA),
    Color(0xFFFFF8E1),
    Color(0xFFFFFFFF),
  ];

  @override
  State<SketchToolbarRich> createState() => _SketchToolbarRichState();
}

class _SketchToolbarRichState extends State<SketchToolbarRich> {
  SketchController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
  }

  @override
  void didUpdateWidget(SketchToolbarRich old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // ── style updates ──────────────────────────────────────────────────────

  void _updateStyle({
    Color? strokeColor,
    Object? fillColor = _sentinel,
    double? strokeWidth,
    double? roughness,
    StrokeStyle? strokeStyle,
    FillStyle? fillStyle,
  }) {
    final s = _ctrl.currentStyle;
    _ctrl.currentStyle = s.copyWith(
      strokeColor: strokeColor,
      fillColor: identical(fillColor, _sentinel)
          ? s.fillColor
          : fillColor as Color?,
      strokeWidth: strokeWidth,
      roughness: roughness,
      strokeStyle: strokeStyle,
      fillStyle: fillStyle,
    );
  }

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.backgroundColor ??
        scheme.surfaceContainerHigh.withValues(alpha: 0.97);
    final style = _ctrl.currentStyle;
    final vertical = widget.orientation == Axis.vertical;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
        child: vertical
            ? _buildVertical(scheme, style)
            : _buildHorizontal(scheme, style),
      ),
    );
  }

  Widget _buildHorizontal(ColorScheme scheme, SketchStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tool in widget.tools) _toolButton(tool),
        _divider(scheme),
        _strokeColorButton(scheme, style),
        _fillColorButton(scheme, style),
        _divider(scheme),
        _strokeWidthButton(style),
        _roughnessButton(style),
        _strokeStyleButton(style),
        _fillStyleButton(style),
        _divider(scheme),
        _undoButton(),
        _redoButton(),
        _clearButton(),
      ],
    );
  }

  Widget _buildVertical(ColorScheme scheme, SketchStyle style) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolGrid(),
        _divider(scheme),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _strokeColorButton(scheme, style),
            _fillColorButton(scheme, style),
          ],
        ),
        _divider(scheme),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _strokeWidthButton(style),
            _roughnessButton(style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _strokeStyleButton(style),
            _fillStyleButton(style),
          ],
        ),
        _divider(scheme),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _undoButton(),
            _redoButton(),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _clearButton(),
          ],
        ),
      ],
    );
  }

  Widget _toolGrid() {
    final rows = <Widget>[];
    for (var i = 0; i < widget.tools.length; i += 2) {
      rows.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolButton(widget.tools[i]),
          if (i + 1 < widget.tools.length) _toolButton(widget.tools[i + 1]),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _toolButton(SketchTool tool) {
    return _ToolButton(
      tool: tool,
      selected: _ctrl.currentTool == tool,
      activeColor: widget.activeColor,
      iconColor: widget.iconColor,
      onTap: () => _ctrl.currentTool = tool,
    );
  }

  Widget _strokeColorButton(ColorScheme scheme, SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Stroke color',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        return _SwatchCircle(color: style.strokeColor, border: scheme.outline);
      },
      popoverBuilder: (context, close) {
        return _PalettePopover(
          palette: widget.palette,
          selected: style.strokeColor,
          onPick: (c) {
            _updateStyle(strokeColor: c);
            close();
          },
        );
      },
    );
  }

  Widget _fillColorButton(ColorScheme scheme, SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Fill color',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        return _SwatchCircle(
          color: style.fillColor,
          border: scheme.outline,
          showNone: style.fillColor == null,
        );
      },
      popoverBuilder: (context, close) {
        return _FillPalettePopover(
          palette: widget.fillPalette,
          selected: style.fillColor,
          onPick: (c) {
            _updateStyle(fillColor: c);
            close();
          },
        );
      },
    );
  }

  Widget _strokeWidthButton(SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Stroke width',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => _StrokeWidthGlyph(
        color: widget.iconColor,
        width: style.strokeWidth,
      ),
      popoverBuilder: (context, close) {
        return _SliderPopover(
          label: 'Stroke width',
          value: style.strokeWidth,
          min: 1.0,
          max: 12.0,
          divisions: 22,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _updateStyle(strokeWidth: v),
        );
      },
    );
  }

  Widget _roughnessButton(SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Roughness',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => Icon(
        Icons.gesture_rounded,
        size: 18,
        color: widget.iconColor,
      ),
      popoverBuilder: (context, close) {
        return _SliderPopover(
          label: 'Roughness',
          value: style.roughness,
          min: 0.0,
          max: 2.5,
          divisions: 25,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _updateStyle(roughness: v),
        );
      },
    );
  }

  Widget _strokeStyleButton(SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Stroke style',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => _StrokeStyleGlyph(
        color: widget.iconColor,
        style: style.strokeStyle,
      ),
      popoverBuilder: (context, close) {
        return _ChoicePopover<StrokeStyle>(
          label: 'Stroke style',
          options: StrokeStyle.values,
          selected: style.strokeStyle,
          labelOf: (s) => s.name,
          onPick: (s) {
            _updateStyle(strokeStyle: s);
            close();
          },
        );
      },
    );
  }

  Widget _fillStyleButton(SketchStyle style) {
    return _PopoverButton(
      tooltip: 'Fill style',
      activeColor: widget.activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => Icon(
        Icons.format_color_fill_rounded,
        size: 18,
        color: widget.iconColor,
      ),
      popoverBuilder: (context, close) {
        return _ChoicePopover<FillStyle>(
          label: 'Fill style',
          options: FillStyle.values,
          selected: style.fillStyle,
          labelOf: (s) => s.name,
          onPick: (s) {
            _updateStyle(fillStyle: s);
            close();
          },
        );
      },
    );
  }

  Widget _undoButton() {
    return _ActionButton(
      icon: Icons.undo_rounded,
      tooltip: 'Undo',
      color: widget.iconColor,
      enabled: _ctrl.canUndo,
      onTap: _ctrl.undo,
    );
  }

  Widget _redoButton() {
    return _ActionButton(
      icon: Icons.redo_rounded,
      tooltip: 'Redo',
      color: widget.iconColor,
      enabled: _ctrl.canRedo,
      onTap: _ctrl.redo,
    );
  }

  Widget _clearButton() {
    return _ActionButton(
      icon: Icons.delete_sweep_rounded,
      tooltip: 'Clear sketches',
      color: widget.iconColor,
      enabled: _ctrl.elements.isNotEmpty,
      onTap: _ctrl.clear,
    );
  }

  Widget _divider(ColorScheme scheme) {
    final vertical = widget.orientation == Axis.vertical;
    return Container(
      width: vertical ? 22 : 1,
      height: vertical ? 1 : 22,
      margin: vertical
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4),
      color: scheme.outlineVariant,
    );
  }
}

const Object _sentinel = Object();

// ─── Building blocks ───────────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.activeColor,
    required this.iconColor,
    required this.onTap,
  });

  final SketchTool tool;
  final bool selected;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tool.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: _ToolGlyph(
              tool: tool,
              color: selected ? activeColor : iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: color.withValues(alpha: enabled ? 1.0 : 0.3),
          ),
        ),
      ),
    );
  }
}

class _PopoverButton extends StatefulWidget {
  const _PopoverButton({
    required this.builder,
    required this.popoverBuilder,
    required this.tooltip,
    required this.activeColor,
    this.vertical = false,
  });

  final Widget Function(BuildContext, _PopoverController) builder;
  final Widget Function(BuildContext, VoidCallback close) popoverBuilder;
  final String tooltip;
  final Color activeColor;
  final bool vertical;

  @override
  State<_PopoverButton> createState() => _PopoverButtonState();
}

class _PopoverController {
  _PopoverController(this._show, this._hide);
  final VoidCallback _show;
  final VoidCallback _hide;
  void show() => _show();
  void hide() => _hide();
}

class _PopoverButtonState extends State<_PopoverButton> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  late final _PopoverController _ctrl = _PopoverController(
    () {
      if (!_portal.isShowing) _portal.show();
    },
    () {
      if (_portal.isShowing) _portal.hide();
    },
  );

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      _portal.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _ctrl.hide,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                  child: CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    targetAnchor: widget.vertical
                        ? Alignment.centerRight
                        : Alignment.bottomLeft,
                    followerAnchor: widget.vertical
                        ? Alignment.centerLeft
                        : Alignment.topLeft,
                    offset: widget.vertical
                        ? const Offset(6, 0)
                        : const Offset(0, 6),
                    child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: widget.popoverBuilder(context, _ctrl.hide),
                  ),
                ),
              ),
            ],
          );
        },
        child: Tooltip(
          message: widget.tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _toggle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: widget.builder(context, _ctrl),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Popovers ──────────────────────────────────────────────────────────

class _PalettePopover extends StatelessWidget {
  const _PalettePopover({
    required this.palette,
    required this.selected,
    required this.onPick,
  });

  final List<Color> palette;
  final Color selected;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
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
                            ? const Color(0xFF2196F3)
                            : const Color(0xFF999999),
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

class _FillPalettePopover extends StatelessWidget {
  const _FillPalettePopover({
    required this.palette,
    required this.selected,
    required this.onPick,
  });

  final List<Color?> palette;
  final Color? selected;
  final ValueChanged<Color?> onPick;

  @override
  Widget build(BuildContext context) {
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
                      color: c ?? const Color(0x00000000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected == c ? 2.5 : 1.0,
                        color: selected == c
                            ? const Color(0xFF2196F3)
                            : const Color(0xFF999999),
                      ),
                    ),
                    child: c == null
                        ? const Icon(Icons.do_not_disturb_alt,
                            size: 14, color: Color(0xFF666666))
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

class _SliderPopover extends StatefulWidget {
  const _SliderPopover({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  State<_SliderPopover> createState() => _SliderPopoverState();
}

class _SliderPopoverState extends State<_SliderPopover> {
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
          ),
        ],
      ),
    );
  }
}

class _ChoicePopover<T> extends StatelessWidget {
  const _ChoicePopover({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onPick,
  });

  final String label;
  final List<T> options;
  final T selected;
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

// ─── Glyphs ────────────────────────────────────────────────────────────

class _SwatchCircle extends StatelessWidget {
  const _SwatchCircle({
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
        color: color ?? const Color(0x00000000),
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
      ),
      child: showNone
          ? const Icon(Icons.do_not_disturb_alt,
              size: 12, color: Color(0xFF666666))
          : null,
    );
  }
}

class _StrokeWidthGlyph extends StatelessWidget {
  const _StrokeWidthGlyph({required this.color, required this.width});

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

class _StrokeStyleGlyph extends StatelessWidget {
  const _StrokeStyleGlyph({required this.color, required this.style});

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

class _ToolGlyph extends StatelessWidget {
  const _ToolGlyph({required this.tool, required this.color});

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
        return Icons.change_history_rounded; // closest fit
      case SketchTool.triangle:
        return Icons.auto_awesome_motion_rounded;
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
      case SketchTool.eraser:
        return Icons.cleaning_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) =>
      Icon(_icon, size: 18, color: color);
}
