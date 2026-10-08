import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/shortcuts/tool_shortcuts.dart';

import 'action_button.dart';
import 'palette_popover.dart';
import 'popover_button.dart';
import 'style_popovers.dart';
import 'tool_button.dart';

/// Full-featured Excalidraw-style toolbar.
///
/// A horizontal bar or — with [orientation] vertical, as the whiteboard
/// uses it — a side rail, exposing:
///
///  * Tool picker, one button per [SketchTool] in [tools].
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
      SketchTool.frame,
      SketchTool.icon,
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

  /// Style fields the current selection disagrees about — resolved at the
  /// top of [build] alongside the theme colors above, and read by the anchor
  /// builders below. See [_resolveDisplayStyle].
  late Set<_MixedField> _mixed;

  /// Shared by the rail's scroll view and its scrollbar, so the bar can show
  /// the rare overflow (a window shorter than the paired layout) instead of
  /// leaving the bottom buttons reachable only by a wheel nobody knows to
  /// turn.
  final ScrollController _scroll = ScrollController();

  /// The stroke colour the current theme supplies for a "just draw" default
  /// — see [_retargetDefaultStroke]. Null until the first dependency pass.
  Color? _themeInk;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retargetDefaultStroke(Theme.of(context).colorScheme);
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
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // ── theme-aware default stroke ─────────────────────────────────────────

  /// `SketchStyle`'s own default stroke: near-black, legible on the light
  /// canvas and all but invisible on the dark theme's navy surface
  /// (contrast ≈ 1.1:1).
  static const Color _lightInk = Color(0xFF1E1E1E);

  /// The stroke colour [scheme] wants a fresh element drawn in: the model's
  /// own default on the light theme, `onSurface` on the dark one.
  static Color _inkFor(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? scheme.onSurface : _lightInk;

  /// Follows a theme change with the default stroke colour — but only while
  /// the colour is *still* the previous theme's default. A stroke the user
  /// picked deliberately (the red swatch, a hex typed into the panel) is
  /// theirs, and stays.
  ///
  /// Deferred a frame: this runs from `didChangeDependencies`, and the
  /// controller's listeners include widgets that are not this one's
  /// descendants, which may not be marked dirty mid-build.
  void _retargetDefaultStroke(ColorScheme scheme) {
    final oldInk = _themeInk ?? _lightInk;
    final newInk = _inkFor(scheme);
    _themeInk = newInk;
    if (newInk == oldInk) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final style = _ctrl.currentStyle;
      if (style.strokeColor != oldInk) return;
      _ctrl.currentStyle = style.copyWith(strokeColor: newInk);
    });
  }

  /// [SketchToolbarRich.palette] with its default first swatch replaced by
  /// the theme's ink, so the rail offers — and rings as current — the
  /// colour new elements are actually drawn in. A caller-supplied palette
  /// is passed through untouched.
  List<Color> _themedPalette() {
    final palette = widget.palette;
    if (palette.isEmpty || palette.first != _lightInk) return palette;
    return [_themeInk ?? _lightInk, ...palette.skip(1)];
  }

  // ── style updates ──────────────────────────────────────────────────────

  /// Applies a toolbar style pick.
  ///
  /// A pick has to land in two places: [SketchController.currentStyle], the
  /// default the *next* element is drawn with, and — whenever there is a
  /// selection — the selected elements themselves. Without the second half
  /// the palette does nothing to the shape the user is looking at, which is
  /// what made the colour controls read as broken (the properties panel has
  /// always restyled the selection, so the two disagreed). The batch goes
  /// through [SketchController.applyStyleToSelected] so one `undo()` reverts
  /// the pick no matter how many elements were selected.
  void _applyStyle(SketchStyle Function(SketchStyle) transform) {
    _ctrl.applyStyleToSelected(transform);
    _ctrl.currentStyle = transform(_ctrl.currentStyle);
  }

  /// Brackets a continuous slider drag so the whole drag collapses into one
  /// history entry instead of one per slider tick. Safe to call with no
  /// selection: the session's snapshot is only pushed by a mutation that
  /// actually happens, and a drag over an empty selection has none.
  void _beginStyleDrag() => _ctrl.beginDragSession();

  void _endStyleDrag() => _ctrl.endDragSession();

  // ── displayed style ────────────────────────────────────────────────────

  /// The style the toolbar should *display*, plus the fields a
  /// multi-element selection disagrees about.
  ///
  /// With a selection the toolbar has to read the selection. Showing
  /// `currentStyle` there means the swatches describe the next element the
  /// user might draw rather than the one they are looking at — the toolbar
  /// quietly lies about the canvas, and there is no way to read an
  /// element's current style before changing it.
  ///
  /// With nothing selected it falls back to `currentStyle`, which is exactly
  /// what the next element will be drawn with.
  ///
  /// Fields that differ across a multi-selection come back in `mixed` and
  /// render as a neutral indicator: letting whichever element happens to be
  /// first speak for all of them is the misleading option. The popovers
  /// still *open* on that first element's value — a slider or a choice list
  /// needs a concrete starting point — but nothing is marked as current
  /// while the field is mixed, and any pick applies to the whole selection.
  ///
  /// Display only. Picks go through [_applyStyle], which derives the new
  /// style from each element's own style and from `currentStyle`, never from
  /// what is shown here, so this cannot feed back into the controller.
  ({SketchStyle style, Set<_MixedField> mixed}) _resolveDisplayStyle() {
    SketchStyle? first;
    final mixed = <_MixedField>{};
    for (final el in _ctrl.elements) {
      if (!_ctrl.isSelected(el.id)) continue;
      final s = el.style;
      if (first == null) {
        first = s;
        continue;
      }
      if (s.strokeColor != first.strokeColor) {
        mixed.add(_MixedField.strokeColor);
      }
      if (s.fillColor != first.fillColor) mixed.add(_MixedField.fillColor);
      if (s.strokeWidth != first.strokeWidth) {
        mixed.add(_MixedField.strokeWidth);
      }
      if (s.roughness != first.roughness) mixed.add(_MixedField.roughness);
      if (s.strokeStyle != first.strokeStyle) {
        mixed.add(_MixedField.strokeStyle);
      }
      if (s.fillStyle != first.fillStyle) mixed.add(_MixedField.fillStyle);
      if (mixed.length == _MixedField.values.length) break;
    }
    return (style: first ?? _ctrl.currentStyle, mixed: mixed);
  }

  /// Neutral anchor glyph standing in for a field the selection disagrees
  /// about.
  Widget _mixedGlyph() =>
      Icon(Icons.more_horiz_rounded, size: 18, color: _iconColor);

  /// Anchor tooltip, flagged when the selection disagrees about [field] —
  /// the neutral glyph on its own doesn't say *why* it went neutral.
  String _tooltipFor(String label, _MixedField field) =>
      _mixed.contains(field) ? '$label — mixed' : label;

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colorScheme = Theme.of(context).colorScheme;
    _activeColor = widget.activeColor ?? _colorScheme.primary;
    _iconColor = widget.iconColor ?? _colorScheme.onSurfaceVariant;

    final bg = widget.backgroundColor ?? _colorScheme.surfaceContainer;
    final display = _resolveDisplayStyle();
    _mixed = display.mixed;
    final style = display.style;
    final vertical = widget.orientation == Axis.vertical;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          // Clipped to the pill: when the rail does have to scroll, content
          // sliding under the rounded ends would otherwise poke out square.
          clipBehavior: Clip.antiAlias,
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
            vertical: _railPaddingY,
          ),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
              child: vertical
                  ? _buildVertical(style, constraints.maxHeight)
                  : _buildHorizontal(style),
            ),
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
          children: [_strokeColorButton(style), _fillColorButton(style)],
        ),
        _divider(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_strokeWidthButton(style), _roughnessButton(style)],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_strokeStyleButton(style), _fillStyleButton(style)],
        ),
        _divider(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_undoButton(), _redoButton()],
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [_clearButton()]),
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
      case SketchTool.frame:
      case SketchTool.icon:
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

  /// Vertical space a section [_divider] occupies — same 1px + 4px margins.
  static const double _sectionDividerHeight = 9.0;

  /// Height of one row of [PopoverButton] anchors (their 32px hit box; they
  /// carry horizontal margin only).
  static const double _anchorRowHeight = 32.0;

  /// Height of one row of [ActionButton]s: 40px plus 2px top/bottom margin.
  static const double _actionRowHeight = 44.0;

  /// The pill's own vertical padding, per side.
  static const double _railPaddingY = 6.0;

  /// Everything in the vertical rail that is *not* the tool grid: the
  /// pill's padding and border, three section dividers, three rows of
  /// style anchors and two rows of history/clear actions
  /// (see [_buildVertical]). The tool grid only gets what is left of the
  /// rail's height after this; comparing the grid alone against the full
  /// height is how the rail used to pick single-column at 720 px and push
  /// its bottom buttons off the window.
  static const double _railChromeHeight =
      _railPaddingY * 2 +
      2 /* border */ +
      3 * _sectionDividerHeight +
      3 * _anchorRowHeight +
      2 * _actionRowHeight;

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
  /// is too short to fit every tool stacked single-file *alongside the
  /// rest of the rail* — the style anchors and actions below the grid
  /// need their share of the height too.
  Widget _toolGrid(double maxHeight) {
    final budget = maxHeight - _railChromeHeight;
    if (_singleColumnToolHeight() <= budget) {
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
        rows.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolButton(pending[i]),
              if (i + 1 < pending.length) _toolButton(pending[i + 1]),
            ],
          ),
        );
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
    if (tool == SketchTool.icon) return _iconToolButton();
    return ToolButton(
      tool: tool,
      selected: _ctrl.currentTool == tool,
      activeColor: _activeColor,
      onActiveColor: _colorScheme.onPrimary,
      iconColor: _iconColor,
      onTap: () => _ctrl.currentTool = tool,
    );
  }

  /// The icon tool's rail slot: a [PopoverButton] sized like a [ToolButton],
  /// whose popover is the catalog grid. Picking a glyph both chooses it and
  /// arms the tool, so one click goes from "which icon" to "place it".
  Widget _iconToolButton() {
    final selected = _ctrl.currentTool == SketchTool.icon;
    return PopoverButton(
      tooltip: ToolShortcuts.tooltip(SketchTool.icon),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      size: 40,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? _activeColor : Colors.transparent,
          borderRadius: AppRadius.mdRadius,
        ),
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: ToolGlyph(
              tool: SketchTool.icon,
              color: selected ? _colorScheme.onPrimary : _iconColor,
            ),
          ),
        ),
      ),
      popoverBuilder: (context, close) => Container(
        width: 224,
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final entry in iconCatalog.entries)
              Tooltip(
                message: entry.key,
                child: InkWell(
                  borderRadius: AppRadius.smRadius,
                  onTap: () {
                    _ctrl.currentIcon = entry.key;
                    _ctrl.currentTool = SketchTool.icon;
                    close();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smRadius,
                      color: _ctrl.currentIcon == entry.key
                          ? _activeColor.withValues(alpha: 0.2)
                          : null,
                    ),
                    child: Icon(entry.value, size: 18, color: _iconColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _strokeColorButton(SketchStyle style) {
    final mixed = _mixed.contains(_MixedField.strokeColor);
    return PopoverButton(
      tooltip: _tooltipFor('Stroke color', _MixedField.strokeColor),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        if (mixed) return _mixedGlyph();
        return SwatchCircle(
          color: style.strokeColor,
          border: _colorScheme.outline,
        );
      },
      popoverBuilder: (context, close) {
        return PalettePopover(
          palette: _themedPalette(),
          selected: mixed ? null : style.strokeColor,
          onPick: (c) {
            _applyStyle((s) => s.copyWith(strokeColor: c));
            close();
          },
        );
      },
    );
  }

  Widget _fillColorButton(SketchStyle style) {
    final mixed = _mixed.contains(_MixedField.fillColor);
    return PopoverButton(
      tooltip: _tooltipFor('Fill color', _MixedField.fillColor),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) {
        if (mixed) return _mixedGlyph();
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
          mixed: mixed,
          onPick: (c) {
            _applyStyle((s) => s.withFillColor(c));
            close();
          },
        );
      },
    );
  }

  Widget _strokeWidthButton(SketchStyle style) {
    return PopoverButton(
      tooltip: _tooltipFor('Stroke width', _MixedField.strokeWidth),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => _mixed.contains(_MixedField.strokeWidth)
          ? _mixedGlyph()
          : StrokeWidthGlyph(color: _iconColor, width: style.strokeWidth),
      popoverBuilder: (context, close) {
        return SliderPopover(
          label: 'Stroke width',
          value: style.strokeWidth,
          min: 1.0,
          max: 12.0,
          divisions: 22,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _applyStyle((s) => s.copyWith(strokeWidth: v)),
          onChangeStart: (_) => _beginStyleDrag(),
          onChangeEnd: (_) => _endStyleDrag(),
        );
      },
    );
  }

  Widget _roughnessButton(SketchStyle style) {
    return PopoverButton(
      tooltip: _tooltipFor('Roughness', _MixedField.roughness),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      // This anchor never previewed a value, so there is nothing for a mixed
      // selection to make neutral — only the tooltip and the popover change.
      builder: (context, controller) =>
          Icon(Icons.gesture_rounded, size: 18, color: _iconColor),
      popoverBuilder: (context, close) {
        return SliderPopover(
          label: 'Roughness',
          value: style.roughness,
          min: 0.0,
          max: 2.5,
          divisions: 25,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => _applyStyle((s) => s.copyWith(roughness: v)),
          onChangeStart: (_) => _beginStyleDrag(),
          onChangeEnd: (_) => _endStyleDrag(),
        );
      },
    );
  }

  Widget _strokeStyleButton(SketchStyle style) {
    final mixed = _mixed.contains(_MixedField.strokeStyle);
    return PopoverButton(
      tooltip: _tooltipFor('Stroke style', _MixedField.strokeStyle),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      builder: (context, controller) => mixed
          ? _mixedGlyph()
          : StrokeStyleGlyph(color: _iconColor, style: style.strokeStyle),
      popoverBuilder: (context, close) {
        return ChoicePopover<StrokeStyle>(
          label: 'Stroke style',
          options: StrokeStyle.values,
          selected: mixed ? null : style.strokeStyle,
          labelOf: (s) => StyleLabels.strokeStyle[s]!,
          onPick: (picked) {
            _applyStyle((s) => s.copyWith(strokeStyle: picked));
            close();
          },
        );
      },
    );
  }

  Widget _fillStyleButton(SketchStyle style) {
    return PopoverButton(
      tooltip: _tooltipFor('Fill style', _MixedField.fillStyle),
      activeColor: _activeColor,
      vertical: widget.orientation == Axis.vertical,
      // Static icon, like the roughness anchor — nothing to neutralise.
      builder: (context, controller) =>
          Icon(Icons.format_color_fill_rounded, size: 18, color: _iconColor),
      popoverBuilder: (context, close) {
        return ChoicePopover<FillStyle>(
          label: 'Fill style',
          options: FillStyle.values,
          selected: _mixed.contains(_MixedField.fillStyle)
              ? null
              : style.fillStyle,
          labelOf: (s) => StyleLabels.fillStyle[s]!,
          onPick: (picked) {
            _applyStyle((s) => s.withFillStyle(picked));
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
      onTap: _clearWithUndo,
    );
  }

  /// Wipes the board and says so, with the way back one tap away. A single
  /// click under undo/redo that empties everything, silently, reads as a
  /// destructive accident; a confirm dialog would be the heavier cure. The
  /// edit was always undoable — this just tells the user.
  void _clearWithUndo() {
    final count = _ctrl.elements.length;
    _ctrl.clear();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Cleared $count ${count == 1 ? 'element' : 'elements'}',
          ),
          action: SnackBarAction(label: 'Undo', onPressed: _ctrl.undo),
        ),
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

/// A style field the toolbar's anchors display, used to mark the ones a
/// multi-element selection disagrees about. See
/// `_SketchToolbarRichState._resolveDisplayStyle`.
enum _MixedField {
  strokeColor,
  fillColor,
  strokeWidth,
  roughness,
  strokeStyle,
  fillStyle,
}
