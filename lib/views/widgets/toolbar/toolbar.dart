import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'action_button.dart';
import 'palette_popover.dart';
import 'popover_button.dart';
import 'style_popovers.dart';
import 'tool_button.dart';

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
/// This widget depends on Flutter Material for the popover anchors. Use
/// it inside a [MaterialApp] or any Material-aware host.
///
/// Orchestration only: this file wires tool selection and opens the
/// right popover for the right button. The button primitives, popover
/// anchor mechanism, and popover contents live alongside it in this
/// `toolbar/` directory as their own single-responsibility files.
class SketchToolbarRich extends StatefulWidget {
  const SketchToolbarRich({
    super.key,
    required this.controller,
    this.palette = defaultPalette,
    this.fillPalette = defaultFillPalette,
    this.backgroundColor,
    this.activeColor,
    this.iconColor,
    this.orientation = Axis.horizontal,
    this.tools = const [
      // Grouped for the tool rail's group dividers: selection/pan | shapes
      // | connectors | annotation. Keep tools that belong to the same
      // visual group adjacent so `_groupIndex` below draws a divider only
      // at true group boundaries.
      SketchTool.select,
      SketchTool.hand,
      SketchTool.rectangle,
      SketchTool.ellipse,
      SketchTool.diamond,
      SketchTool.triangle,
      SketchTool.sticky,
      SketchTool.line,
      SketchTool.arrow,
      SketchTool.freedraw,
      SketchTool.text,
      SketchTool.eraser,
    ],
  });

  final SketchController controller;
  final List<Color> palette;
  final List<Color?> fillPalette;
  final Color? backgroundColor;

  /// Highlight color for the selected tool/anchor. Defaults to
  /// `Theme.of(context).colorScheme.primary` when null.
  final Color? activeColor;

  /// Icon color for unselected tools/anchors. Defaults to
  /// `Theme.of(context).colorScheme.onSurfaceVariant` when null.
  final Color? iconColor;

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

  /// Resolved live-theme colors for the current build — set at the top of
  /// [build] and read by every helper method below instead of reaching
  /// into `AppColors` (which only ever holds the dark palette) or
  /// [SketchToolbarRich]'s now-nullable `activeColor`/`iconColor` fields
  /// directly.
  late ColorScheme _colorScheme;
  late Color _activeColor;
  late Color _iconColor;

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
    _colorScheme = Theme.of(context).colorScheme;
    _activeColor = widget.activeColor ?? _colorScheme.primary;
    _iconColor = widget.iconColor ?? _colorScheme.onSurfaceVariant;

    final bg = widget.backgroundColor ?? _colorScheme.surfaceContainer;
    final style = _ctrl.currentStyle;
    final vertical = widget.orientation == Axis.vertical;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.fullRadius,
            border: Border.all(color: _colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.toolbarGap,
            vertical: 6,
          ),
          child: SingleChildScrollView(
            scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
            child: vertical
                ? _buildVertical(style, constraints.maxHeight)
                : _buildHorizontal(style),
          ),
        );
      },
    );
  }

  Widget _buildHorizontal(SketchStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._groupedToolRow(),
        _divider(),
        _strokeColorButton(style),
        _fillColorButton(style),
        _divider(),
        _strokeWidthButton(style),
        _roughnessButton(style),
        _strokeStyleButton(style),
        _fillStyleButton(style),
        _divider(),
        _undoButton(),
        _redoButton(),
        _clearButton(),
      ],
    );
  }

  Widget _buildVertical(SketchStyle style, double maxHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolGrid(maxHeight),
        _divider(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _strokeColorButton(style),
            _fillColorButton(style),
          ],
        ),
        _divider(),
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
        _divider(),
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

  /// Tool-rail group: select/hand | shapes | connectors | annotation.
  /// Drives where [_toolGrid] / [_groupedToolRow] insert a group divider.
  int _groupIndex(SketchTool tool) {
    switch (tool) {
      case SketchTool.select:
      case SketchTool.hand:
        return 0;
      case SketchTool.rectangle:
      case SketchTool.ellipse:
      case SketchTool.diamond:
      case SketchTool.triangle:
      case SketchTool.sticky:
        return 1;
      case SketchTool.line:
      case SketchTool.arrow:
        return 2;
      case SketchTool.freedraw:
      case SketchTool.text:
      case SketchTool.eraser:
        return 3;
    }
  }

  /// Cell height of a single [ToolButton]: its 40px hit target plus the
  /// 2px top/bottom margin `ToolButton` wraps itself in.
  static const double _toolCellHeight = 44.0;

  /// Vertical space a [_groupDivider] occupies: its 1px line plus the 4px
  /// top/bottom margin.
  static const double _groupDividerHeight = 9.0;

  /// Height a single-column tool rail (one [ToolButton] per row, plus a
  /// group divider at each group boundary) would need — matches the
  /// source design's "one icon per row" layout.
  double _singleColumnToolHeight() {
    var groupBoundaries = 0;
    int? lastGroup;
    for (final tool in widget.tools) {
      final group = _groupIndex(tool);
      if (lastGroup != null && group != lastGroup) groupBoundaries++;
      lastGroup = group;
    }
    return widget.tools.length * _toolCellHeight +
        groupBoundaries * _groupDividerHeight;
  }

  /// Vertical tool rail. Defaults to a single column — one [ToolButton]
  /// per row — matching the source design, which never shows two tool
  /// icons side by side. Only falls back to the denser 2-column pairing
  /// when [maxHeight] (the actual space available to the whole toolbar)
  /// is too short to fit every tool stacked single-file.
  Widget _toolGrid(double maxHeight) {
    if (_singleColumnToolHeight() <= maxHeight) {
      return _toolColumnSingle();
    }
    return _toolGridPaired();
  }

  /// Single-column tool rail: one [ToolButton] per row, with a thin
  /// divider between tool-rail groups.
  Widget _toolColumnSingle() {
    final children = <Widget>[];
    int? lastGroup;
    for (final tool in widget.tools) {
      final group = _groupIndex(tool);
      if (lastGroup != null && group != lastGroup) {
        children.add(_groupDivider());
      }
      children.add(_toolButton(tool));
      lastGroup = group;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Fallback vertical tool rail: a 2-column grid per group, with a thin
  /// divider between groups (2-column pairing restarts at each group
  /// boundary so odd-sized groups don't visually bleed into the next
  /// one). Used only when [_toolColumnSingle] wouldn't fit the available
  /// height.
  Widget _toolGridPaired() {
    final rows = <Widget>[];
    var pending = <SketchTool>[];
    int? lastGroup;

    void flush() {
      for (var i = 0; i < pending.length; i += 2) {
        rows.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolButton(pending[i]),
            if (i + 1 < pending.length) _toolButton(pending[i + 1]),
          ],
        ));
      }
      pending = [];
    }

    for (final tool in widget.tools) {
      final group = _groupIndex(tool);
      if (lastGroup != null && group != lastGroup) {
        flush();
        rows.add(_groupDivider());
      }
      pending.add(tool);
      lastGroup = group;
    }
    flush();

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  /// Horizontal tool row: same group-divider rule as [_toolGrid], without
  /// 2-column pairing.
  List<Widget> _groupedToolRow() {
    final children = <Widget>[];
    int? lastGroup;
    for (final tool in widget.tools) {
      final group = _groupIndex(tool);
      if (lastGroup != null && group != lastGroup) {
        children.add(_groupDivider());
      }
      children.add(_toolButton(tool));
      lastGroup = group;
    }
    return children;
  }

  Widget _toolButton(SketchTool tool) {
    return ToolButton(
      tool: tool,
      selected: _ctrl.currentTool == tool,
      activeColor: _activeColor,
      onActiveColor: _colorScheme.onPrimary,
      iconColor: _iconColor,
      onTap: () => _ctrl.currentTool = tool,
    );
  }

  Widget _strokeColorButton(SketchStyle style) {
    return PopoverButton(
      tooltip: 'Stroke color',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        return SwatchCircle(
          color: style.strokeColor,
          border: _colorScheme.outline,
        );
      },
      popoverBuilder: (context, close) {
        return PalettePopover(
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

  Widget _fillColorButton(SketchStyle style) {
    return PopoverButton(
      tooltip: 'Fill color',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        return SwatchCircle(
          color: style.fillColor,
          border: _colorScheme.outline,
          showNone: style.fillColor == null,
        );
      },
      popoverBuilder: (context, close) {
        return FillPalettePopover(
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
    return PopoverButton(
      tooltip: 'Stroke width',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => StrokeWidthGlyph(
        color: _iconColor,
        width: style.strokeWidth,
      ),
      popoverBuilder: (context, close) {
        return SliderPopover(
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
    return PopoverButton(
      tooltip: 'Roughness',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => Icon(
        Icons.gesture_rounded,
        size: 18,
        color: _iconColor,
      ),
      popoverBuilder: (context, close) {
        return SliderPopover(
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
    return PopoverButton(
      tooltip: 'Stroke style',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => StrokeStyleGlyph(
        color: _iconColor,
        style: style.strokeStyle,
      ),
      popoverBuilder: (context, close) {
        return ChoicePopover<StrokeStyle>(
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
    return PopoverButton(
      tooltip: 'Fill style',
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => Icon(
        Icons.format_color_fill_rounded,
        size: 18,
        color: _iconColor,
      ),
      popoverBuilder: (context, close) {
        return ChoicePopover<FillStyle>(
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
    return ActionButton(
      icon: Icons.undo_rounded,
      tooltip: 'Undo',
      color: _iconColor,
      enabled: _ctrl.canUndo,
      onTap: _ctrl.undo,
    );
  }

  Widget _redoButton() {
    return ActionButton(
      icon: Icons.redo_rounded,
      tooltip: 'Redo',
      color: _iconColor,
      enabled: _ctrl.canRedo,
      onTap: _ctrl.redo,
    );
  }

  Widget _clearButton() {
    return ActionButton(
      icon: Icons.delete_sweep_rounded,
      tooltip: 'Clear sketches',
      color: _iconColor,
      enabled: _ctrl.elements.isNotEmpty,
      onTap: _ctrl.clear,
    );
  }

  Widget _divider() {
    final vertical = widget.orientation == Axis.vertical;
    return Container(
      width: vertical ? 22 : 1,
      height: vertical ? 1 : 22,
      margin: vertical
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4),
      color: _colorScheme.outlineVariant,
    );
  }

  /// Divider between tool-rail groups (selection/pan | shapes | connectors
  /// | annotation) — thinner and tighter than [_divider].
  Widget _groupDivider() {
    final vertical = widget.orientation == Axis.vertical;
    return Container(
      width: vertical ? 32 : 1,
      height: vertical ? 1 : 32,
      margin: vertical
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4),
      color: _colorScheme.outlineVariant,
    );
  }
}

const Object _sentinel = Object();
