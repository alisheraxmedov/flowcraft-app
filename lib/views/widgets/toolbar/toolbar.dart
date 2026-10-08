import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/canvas_ink.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'package:flowcraft/views/widgets/glass/glass_island.dart';

import 'tool_button.dart';

/// The tool island: Glass Canvas's centred pill of tools.
///
/// One [ToolButton] per [SketchTool] in [tools], in groups (selection / shapes
/// / connectors / annotation) split by hairline dividers, the icon tool
/// opening the catalog grid. The style controls, undo/redo and clear that
/// used to share this bar live in the inspector, the bottom island and the
/// Edit menu respectively — every control exists once.
///
/// It is as wide as its tools; when the host gives it less (a narrow window)
/// it scrolls horizontally instead of overflowing.
///
/// [palette], [fillPalette], [backgroundColor], [activeColor], [iconColor] and
/// [orientation] are accepted and ignored so existing call sites compile; the
/// look comes from the theme's [FcTokens].
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
  final Color? activeColor;
  final Color? iconColor;
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

  /// Shared by the scroll view and its scrollbar, for the narrow-window
  /// fallback.
  final ScrollController _scroll = ScrollController();

  /// The stroke colour the current theme supplies for a "just draw" default
  /// -- see [_retargetDefaultStroke]. Null until the first dependency pass.
  Color? _themeInk;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retargetDefaultStroke(Theme.of(context).brightness);
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

  // -- theme-aware default stroke -------------------------------------------

  /// Follows a theme change with the default stroke colour -- but only while
  /// the colour is *still* the previous theme's default. A stroke the user
  /// picked deliberately (the red swatch, a hex typed into the inspector) is
  /// theirs, and stays.
  ///
  /// Deferred a frame: this runs from `didChangeDependencies`, and the
  /// controller's listeners include widgets that are not this one's
  /// descendants, which may not be marked dirty mid-build.
  void _retargetDefaultStroke(Brightness brightness) {
    final oldInk = _themeInk ?? lightInk;
    final newInk = inkFor(brightness);
    _themeInk = newInk;
    if (newInk == oldInk) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final style = _ctrl.currentStyle;
      if (style.strokeColor != oldInk) return;
      _ctrl.currentStyle = style.copyWith(strokeColor: newInk);
    });
  }

  // -- build ----------------------------------------------------------------

  /// Tool group: select/hand | shapes | connectors | annotation. Drives where
  /// a divider is inserted.
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

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final children = <Widget>[];
    int? lastGroup;
    for (final tool in widget.tools) {
      final group = _groupIndex(tool);
      if (lastGroup != null && group != lastGroup) {
        children.add(
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: t.glassBorder,
          ),
        );
      }
      children.add(_toolButton(tool));
      lastGroup = group;
    }

    return SizedBox(
      height: 52,
      child: GlassIsland(
        radius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }

  Widget _toolButton(SketchTool tool) {
    if (tool == SketchTool.icon) return _iconToolButton();
    return ToolButton(
      tool: tool,
      selected: _ctrl.currentTool == tool,
      onTap: () => _ctrl.currentTool = tool,
    );
  }

  /// The icon tool's slot: a [ToolButton] whose popover is the catalog grid.
  /// Picking a glyph both chooses it and arms the tool, so one click goes
  /// from "which icon" to "place it".
  Widget _iconToolButton() {
    final t = context.fc;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        SizedBox(
          width: 224,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final entry in iconCatalog.entries)
                Builder(
                  builder: (context) => Tooltip(
                    message: entry.key,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      onTap: () {
                        _ctrl.currentIcon = entry.key;
                        _ctrl.currentTool = SketchTool.icon;
                        MenuController.maybeOf(context)?.close();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          color: _ctrl.currentIcon == entry.key
                              ? t.accentTint
                              : null,
                        ),
                        // Canvas-content glyphs (iconCatalog), not chrome.
                        child: Icon(entry.value, size: 18, color: t.text),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, menu, _) => ToolButton(
        tool: SketchTool.icon,
        selected: _ctrl.currentTool == SketchTool.icon,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
