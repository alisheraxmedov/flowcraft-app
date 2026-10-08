import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/canvas/grid_painter.dart';
import 'package:flowcraft/core/canvas/whiteboard_canvas.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/viewmodels/canvas_preferences.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/viewmodels/theme_view_model.dart';
import 'package:flowcraft/views/widgets/agents_popover.dart';
import 'package:flowcraft/views/widgets/canvas_shortcuts.dart';
import 'package:flowcraft/views/widgets/edit_menu_button.dart';
import 'package:flowcraft/views/widgets/export_menu_button.dart';
import 'package:flowcraft/views/widgets/glass/fc_icon_button.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flowcraft/views/widgets/partial_scene_banner.dart';
import 'package:flowcraft/views/widgets/project_title_field.dart';
import 'package:flowcraft/views/widgets/projects_popover.dart';
import 'package:flowcraft/views/widgets/properties_panel.dart';
import 'package:flowcraft/views/widgets/toolbar/toolbar.dart';

/// Window edge to floating chrome, and the top of the inspector/banner row
/// (16 gutter + 48 island + 16), per the Glass Canvas mockup.
const double _gutter = 16;
const double _belowTopRow = 80;

/// Width the tool pill leaves free on each side for the top islands, so the
/// pill stays centred on the *window* as in the mockup (a Row would centre
/// it between two islands of different widths). It scrolls when squeezed.
const double _pillSideReserve = 316;

/// The whiteboard screen: a full-bleed canvas under five floating glass
/// islands (top-left brand/project, top-centre tools, top-right
/// agents/edit/export, left inspector, bottom-right undo/redo/grid/theme).
/// Every control exists exactly once.
class WhiteboardView extends ConsumerStatefulWidget {
  const WhiteboardView({super.key});

  @override
  ConsumerState<WhiteboardView> createState() => _WhiteboardViewState();
}

class _WhiteboardViewState extends ConsumerState<WhiteboardView> {
  bool _showGrid = true;

  @override
  Widget build(BuildContext context) {
    // `read`, not `watch` — the canvas, tool pill, inspector and bottom
    // island listen to the controller themselves; this view doesn't need to
    // rebuild on every canvas edit.
    final sketch = ref.read(sketchControllerProvider);
    final isDark = ref.watch(themeViewModelProvider);
    final t = context.fc;

    // Wrapped around the whole Scaffold, not the canvas: the shortcut layer
    // has to keep working while focus sits in the toolbar or a properties
    // field.
    return CanvasShortcuts(
      controller: sketch,
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: WhiteboardCanvas(
                sketchController: sketch,
                animateReveal: ref.watch(animateAgentDrawingProvider),
                gridType: _showGrid ? GridType.dots : GridType.none,
                backgroundColor: t.bg,
                gridColor: t.dot,
              ),
            ),
            const Positioned(
              left: _gutter,
              top: _gutter,
              child: _BrandIsland(),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _gutter,
              child: LayoutBuilder(
                builder: (context, c) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: math.min(_pillSideReserve, c.maxWidth / 4),
                  ),
                  child: Center(child: SketchToolbarRich(controller: sketch)),
                ),
              ),
            ),
            Positioned(
              right: _gutter,
              top: _gutter,
              child: _ActionsIsland(controller: sketch),
            ),
            // Content-height and pinned top-left: the panel is as tall as its
            // sections, and a bare Positioned would stretch it to `bottom`.
            // Its own scroll view takes over when a short window clips it.
            Positioned(
              left: _gutter,
              top: _belowTopRow,
              bottom: _gutter,
              child: Align(
                alignment: Alignment.topLeft,
                child: PropertiesPanel(controller: sketch),
              ),
            ),
            Positioned(
              right: _gutter,
              bottom: _gutter,
              child: _ViewIsland(
                controller: sketch,
                showGrid: _showGrid,
                isDark: isDark,
                onToggleGrid: () => setState(() => _showGrid = !_showGrid),
                onToggleTheme: () =>
                    ref.read(themeViewModelProvider.notifier).toggle(),
              ),
            ),
            // Last, because it says the user's edits are not being saved —
            // the one message on this screen that must not sit behind a
            // floating island.
            Positioned(
              top: _belowTopRow,
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

/// Top-left island: logo, product name, "/", the open project's name
/// (click to rename) and the Projects popover button.
class _BrandIsland extends StatefulWidget {
  const _BrandIsland();

  @override
  State<_BrandIsland> createState() => _BrandIslandState();
}

class _BrandIslandState extends State<_BrandIsland> {
  /// The island itself is the Projects popover's anchor (mockup: left-aligned
  /// with the island, 8px below it), not the small button inside it.
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final muted = AppTypography.bodySm.copyWith(color: t.muted, height: 1.2);
    return CompositedTransformTarget(
      link: _link,
      child: GlassIsland(
        // Mockup padding 14/8 plus its 1px border; `GlassIsland` paints the
        // border inside its box, so the border width is added here. Right 7 +
        // the button's own 2px margin = 9.
        padding: const EdgeInsets.fromLTRB(15, 0, 7, 0),
        child: SizedBox(
          height: 48, // mockup outer height; the border paints inside it
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoGlyph(),
              const SizedBox(width: 8),
              Text(
                'FlowCraft',
                style: muted.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Text('/', style: muted),
              const SizedBox(width: 8),
              // Renders nothing until a project is open, so no placeholder
              // gap appears during the first load.
              const Flexible(child: ProjectTitleField()),
              // 6 + the popover button's own 2px margin = the mockup's 8 gap.
              const SizedBox(width: 6),
              ProjectsButton(anchorLink: _link),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mockup's 24px logo: an accent-tinted rounded square (the theme's own
/// `accentTint`, so light 12% / dark 16% are both right) with the accent
/// outline and squiggle on top.
class _LogoGlyph extends StatelessWidget {
  const _LogoGlyph();

  static const _outline = FcIcon('logoOutline', [
    FcRect(2, 2, 20, 20, rx: 6),
    FcPath('M6.5 15.5 C 9 7, 13 17, 17.5 8.5'),
  ]);

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // viewBox 2..22 of 24 → a 20px square inset 2px.
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: t.accentTint,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          FcIconGlyph(_outline, size: 24, color: t.accent),
        ],
      ),
    );
  }
}

/// Top-right island: Agents chip, Edit menu, Export (the only filled
/// button).
class _ActionsIsland extends StatelessWidget {
  const _ActionsIsland({required this.controller});

  final SketchController controller;

  @override
  Widget build(BuildContext context) {
    return GlassIsland(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 46,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AgentsChip(),
            const SizedBox(width: 6),
            // The mouse route to the shortcut layer — every command it
            // binds, with its key printed beside it.
            EditMenuButton(controller: controller),
            const SizedBox(width: 6),
            // The open project's name seeds the export filename.
            Consumer(
              builder: (context, ref, _) => ExportMenuButton(
                controller: controller,
                documentName: ref.watch(projectsViewModelProvider).active?.name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-right island: Undo, Redo | Grid, Theme. Listens to the controller
/// so Undo/Redo track canUndo/canRedo without the screen rebuilding.
class _ViewIsland extends StatelessWidget {
  const _ViewIsland({
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
  Widget build(BuildContext context) {
    final t = context.fc;
    return GlassIsland(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 42, // 44 outer minus the 1px border either side
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FcIconButton(
                icon: FcIcons.undo2,
                tooltip: 'Undo',
                onPressed: controller.canUndo ? controller.undo : null,
              ),
              const SizedBox(width: 2),
              FcIconButton(
                icon: FcIcons.redo2,
                tooltip: 'Redo',
                onPressed: controller.canRedo ? controller.redo : null,
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: t.glassBorder,
              ),
              FcIconButton(
                icon: FcIcons.grid3x3,
                tooltip: showGrid ? 'Hide grid' : 'Show grid',
                pressed: showGrid,
                onPressed: onToggleGrid,
              ),
              const SizedBox(width: 2),
              FcIconButton(
                icon: isDark ? FcIcons.sun : FcIcons.moon,
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                onPressed: onToggleTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
