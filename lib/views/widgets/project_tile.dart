import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/core/utils/relative_time.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/toolbar/popover_button.dart';

/// One row in the projects popover: 52px, radius 12, name + meta line (+ a
/// mono linked-file line), and a "…" Project actions menu.
///
/// A [FlowProject] whose file failed to parse renders as a danger-tinted,
/// unopenable row rather than being hidden — a project the user can see and
/// delete is far less alarming than one that silently disappeared.
class ProjectTile extends StatefulWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onLink,
    required this.onUnlink,
  });

  final FlowProject project;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  @override
  State<ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<ProjectTile> {
  bool _hover = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final project = widget.project;
    final broken = project.isBroken;
    final active = widget.isActive;
    final shape = BorderRadius.circular(AppRadius.row);
    final bg = broken
        ? t.dangerTint
        : active
        ? t.accentTint
        : (_hover || _menuOpen)
        ? t.surface2
        : null;

    return Semantics(
      selected: active,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Stack(
          children: [
            Material(
              color: bg ?? Colors.transparent,
              borderRadius: shape,
              child: InkWell(
                borderRadius: shape,
                hoverColor: Colors.transparent,
                onTap: broken ? null : widget.onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    // Right 52 reserves the "…" button on every row so the
                    // text never reflows when the button appears on hover.
                    padding: const EdgeInsets.fromLTRB(12, 8, 52, 8),
                    child: Row(
                      children: [
                        // 8px accent dot; inactive rows keep the 8px gap.
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? t.accent : null,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 13.5,
                                  height: 18 / 13.5,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: broken ? t.danger : t.text,
                                ),
                              ),
                              Text(
                                _subtitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  color: broken ? t.danger : t.muted,
                                ),
                              ),
                              if (project.linkedPath != null)
                                Text(
                                  project.linkedPath!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.mono11.copyWith(
                                    color: t.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 10,
              // Visible on hover / while its menu is open (mockup), but kept
              // in the tree and tappable so keyboard and tests reach it.
              child: _RowMenu(
                visible: _hover || _menuOpen,
                canRename: !broken,
                isLinked: project.linkedPath != null,
                onLink: widget.onLink,
                onUnlink: widget.onUnlink,
                onRename: widget.onRename,
                onDelete: widget.onDelete,
                // The host reports its disposal a frame late; by then the tile
                // itself may be gone (project deleted, popover torn down).
                onOpenChanged: (open) {
                  if (mounted) setState(() => _menuOpen = open);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (widget.project.isBroken) return "Can't be read";
    final count = widget.project.elementCount;
    return '$count element${count == 1 ? '' : 's'} · '
        '${RelativeTime.format(widget.project.updatedAt)}';
  }
}

/// The "…" button and its menu, a [PopoverButton] like the other glass
/// popovers.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.canRename,
    required this.isLinked,
    required this.onLink,
    required this.onUnlink,
    required this.onRename,
    required this.onDelete,
    required this.visible,
    required this.onOpenChanged,
  });

  final bool canRename;
  final bool isLinked;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  /// Glyph shown only while the row is hovered or the menu is open.
  final bool visible;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return PopoverButton(
      tooltip: 'Project actions',
      activeColor: t.accent,
      anchor: PopoverAnchor.belowEnd,
      radius: AppRadius.row,
      // Raised 32px chip with the soft double shadow, per the mockup.
      builder: (context, _) => Opacity(
        opacity: visible ? 1 : 0,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.raised,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: t.raisedShadow,
          ),
          child: FcIconGlyph(FcIcons.ellipsis, size: 16, color: t.text),
        ),
      ),
      popoverBuilder: (context, close) => _MenuHost(
        onOpenChanged: onOpenChanged,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MenuItem(
                    icon: FcIcons.pencil,
                    label: 'Rename',
                    onTap: canRename ? () => _run(close, onRename) : null,
                  ),
                  if (isLinked)
                    _MenuItem(
                      icon: FcIcons.unlink,
                      label: 'Unlink file',
                      onTap: () => _run(close, onUnlink),
                    )
                  else
                    _MenuItem(
                      icon: FcIcons.link,
                      label: 'Link to file…',
                      onTap: canRename ? () => _run(close, onLink) : null,
                    ),
                  _MenuItem(
                    icon: FcIcons.trash,
                    label: 'Delete',
                    danger: true,
                    onTap: () => _run(close, onDelete),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _run(VoidCallback close, VoidCallback action) {
    close();
    action();
  }
}

/// Reports the menu's open/closed lifetime so the row can stay "hovered"
/// while its menu (which swallows pointer hover) is up.
class _MenuHost extends StatefulWidget {
  const _MenuHost({required this.onOpenChanged, required this.child});

  final ValueChanged<bool> onOpenChanged;
  final Widget child;

  @override
  State<_MenuHost> createState() => _MenuHostState();
}

class _MenuHostState extends State<_MenuHost> {
  late final ValueChanged<bool> _notify = widget.onOpenChanged;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify(true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 32px menu row, radius 8, 13px text, 15px glyph, danger variant.
class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final FcIcon icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final color = widget.danger ? t.danger : t.text;
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _hover && enabled ? t.surface2 : null,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                FcIconGlyph(widget.icon, size: 15, color: color),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: AppTypography.bodySm.copyWith(height: 1, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
