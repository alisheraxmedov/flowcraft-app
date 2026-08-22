import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/canvas/grid_painter.dart';
import 'package:flowcraft/core/canvas/whiteboard_canvas.dart';
import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/viewmodels/theme_view_model.dart';
import 'package:flowcraft/views/widgets/canvas_shortcuts.dart';
import 'package:flowcraft/views/widgets/edit_menu_button.dart';
import 'package:flowcraft/views/widgets/export_menu_button.dart';
import 'package:flowcraft/views/widgets/mcp_card.dart';
import 'package:flowcraft/views/widgets/partial_scene_banner.dart';
import 'package:flowcraft/views/widgets/project_drawer.dart';
import 'package:flowcraft/views/widgets/project_title_field.dart';
import 'package:flowcraft/views/widgets/properties_panel.dart';
import 'package:flowcraft/views/widgets/toolbar/toolbar.dart';

/// Height of the top app bar. Matches Flutter's own [kToolbarHeight]
/// default, pinned explicitly (via [AppBar.toolbarHeight] below) so the
/// floating overlays' offset math in [WhiteboardView] doesn't silently
/// drift if that Material default ever changes.
const double _topBarHeight = 56.0;

/// The whiteboard screen: canvas + chrome (top bar, floating tool rail,
/// properties panel, MCP/system card). Reads the sketch, theme, and MCP
/// view models via Riverpod instead of manual prop-drilling.
class WhiteboardView extends ConsumerStatefulWidget {
  const WhiteboardView({super.key});

  @override
  ConsumerState<WhiteboardView> createState() => _WhiteboardViewState();
}

class _WhiteboardViewState extends ConsumerState<WhiteboardView> {
  bool _showGrid = true;

  @override
  Widget build(BuildContext context) {
    // `read`, not `watch` — WhiteboardCanvas/SketchToolbarRich/_TopBar/
    // PropertiesPanel listen to the controller themselves; this view
    // doesn't need to rebuild on every canvas edit.
    final sketch = ref.read(sketchControllerProvider);
    final isDark = ref.watch(themeViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Wrapped around the whole Scaffold, not the canvas: the shortcut layer
    // has to keep working while focus sits in the toolbar, a properties
    // field or the drawer, which is exactly what the old canvas-scoped key
    // handler could not do.
    return CanvasShortcuts(
      controller: sketch,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        // The saved-project sidebar. `Scaffold.drawer` rather than a panel in
        // the body Stack: it has to overlay the tool rail, which already owns
        // the left gutter.
        drawer: const ProjectDrawer(),
        appBar: _TopBar(
          controller: sketch,
          showGrid: _showGrid,
          isDark: isDark,
          onToggleGrid: () => setState(() => _showGrid = !_showGrid),
          onToggleTheme: () =>
              ref.read(themeViewModelProvider.notifier).toggle(),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: WhiteboardCanvas(
                sketchController: sketch,
                gridType: _showGrid ? GridType.dots : GridType.none,
                backgroundColor: colorScheme.surface,
                gridColor: colorScheme.outline,
              ),
            ),
            // `Scaffold.body`'s origin already starts below the app bar, so
            // this rail only needs to span the body's own height — no
            // `_topBarHeight` offset here (unlike the pre-AppBar layout).
            Positioned(
              left: AppSpacing.gutter,
              top: 0,
              bottom: 0,
              child: Center(
                child: SketchToolbarRich(
                  controller: sketch,
                  orientation: Axis.vertical,
                ),
              ),
            ),
            // Same reasoning, but this one keeps its `gutter` margin below
            // the (now implicit) app bar boundary.
            Positioned(
              top: AppSpacing.gutter,
              right: AppSpacing.gutter,
              child: PropertiesPanel(controller: sketch),
            ),
            const Positioned(
              right: AppSpacing.gutter,
              bottom: AppSpacing.gutter,
              child: McpCard(),
            ),
            // Above everything, because it says the user's edits are not
            // being saved — the one message on this screen that must not sit
            // behind a floating panel.
            Positioned(
              top: AppSpacing.toolbarGap,
              left: 0,
              right: 0,
              child: Center(child: PartialSceneBanner(controller: sketch)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed, translucent-blurred top app bar. Self-listens to [controller] so
/// the undo/redo/delete buttons reflect live canvas state without the
/// parent view rebuilding on every edit.
///
/// A real [AppBar] (hosted via `Scaffold.appBar`) rather than a hand-rolled
/// `Positioned` + `BackdropFilter` row, so it gets Scaffold's standard
/// layout behavior (the body's origin starts below it automatically) while
/// keeping the same translucent-blur look via [AppBar.flexibleSpace].
class _TopBar extends StatefulWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.controller,
    required this.showGrid,
    required this.isDark,
    required this.onToggleGrid,
    required this.onToggleTheme,
  });

  final SketchController controller;
  final bool showGrid;
  final bool isDark;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleTheme;

  @override
  Size get preferredSize => const Size.fromHeight(_topBarHeight);

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_TopBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: _topBarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Left to Material, which supplies the button that opens the
      // project drawer hung off the Scaffold above.
      titleSpacing: AppSpacing.gutter,
      actionsPadding: EdgeInsets.zero,
      // Same translucent-blur background + bottom hairline as the old
      // hand-rolled top bar, now living behind the toolbar row instead of
      // being the toolbar row's own decoration.
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceDim.withValues(alpha: 0.8),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.architecture_outlined,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          // Just the product name now — the open project's own name sits
          // beside it, and repeating "Whiteboard" next to it read as noise.
          Flexible(
            child: Text(
              'FlowCraft',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTypography.headlineMd.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const _HeaderDivider(),
          // Renders nothing until a project is open, so no placeholder gap
          // appears during the first load.
          const Flexible(child: ProjectTitleField()),
        ],
      ),
      actions: [
        // A `Flexible` + horizontally-scrolling row (rather than a plain
        // list of actions) so the trailing controls degrade to a
        // scrollable strip instead of overflow-asserting when the window
        // is narrower than their natural width.
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The mouse route to the shortcut layer — every command it
                // binds, with its key printed beside it.
                EditMenuButton(controller: ctrl),
                const _HeaderDivider(),
                _HeaderIconButton(
                  icon: widget.showGrid
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  tooltip: widget.showGrid ? 'Hide grid' : 'Show grid',
                  onTap: widget.onToggleGrid,
                ),
                const _HeaderDivider(),
                _HeaderIconButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: ctrl.canUndo,
                  onTap: ctrl.undo,
                ),
                _HeaderIconButton(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: ctrl.canRedo,
                  onTap: ctrl.redo,
                ),
                const _HeaderDivider(),
                _HeaderIconButton(
                  icon: widget.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
                  onTap: widget.onToggleTheme,
                ),
                _HeaderIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete selected',
                  enabled: ctrl.hasSelection,
                  color: colorScheme.error,
                  onTap: ctrl.removeSelected,
                ),
                const SizedBox(width: 12),
                // `_TopBar` is a plain StatefulWidget with no `ref`, so the
                // open project's name — which seeds the export filename —
                // is read through a local Consumer.
                Consumer(
                  builder: (context, ref, _) => ExportMenuButton(
                    controller: ctrl,
                    documentName:
                        ref.watch(projectsViewModelProvider).active?.name,
                  ),
                ),
                const SizedBox(width: AppSpacing.gutter),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = color ?? colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppRadius.xsRadius,
        hoverColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: iconColor.withValues(alpha: enabled ? 1.0 : 0.35),
          ),
        ),
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
