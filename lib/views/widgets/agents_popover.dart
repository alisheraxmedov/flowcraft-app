import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/services/app_version.dart';
import 'package:flowcraft/viewmodels/canvas_preferences.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/glass/fc_switch.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';
import 'package:flowcraft/views/widgets/mcp_setup_dialog.dart';

/// How each server state reads, resolved in one place so the chip's dot, the
/// popover's status pill and its switch can never disagree.
({String label, Color dot, Color pillBg, Color pillFg}) agentsPresentation(
  McpServerStatus status,
  FcTokens t,
) {
  return switch (status.state) {
    McpServerState.running => (
      label: 'Online',
      dot: t.ok,
      pillBg: t.ok.withValues(alpha: 0.15),
      pillFg: Color.lerp(t.text, t.ok, 0.78)!,
    ),
    McpServerState.starting => (
      label: 'Starting…',
      dot: t.muted,
      pillBg: t.muted.withValues(alpha: 0.15),
      pillFg: t.muted,
    ),
    McpServerState.off => (
      label: 'Offline',
      dot: t.muted,
      pillBg: t.muted.withValues(alpha: 0.15),
      pillFg: t.muted,
    ),
    McpServerState.failed => (
      label: 'Failed to start',
      dot: t.danger,
      pillBg: t.dangerTint,
      pillFg: t.danger,
    ),
  };
}

TextStyle _text(double size, FontWeight weight, Color color, {double? lineH}) =>
    AppTypography.bodyBase.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: lineH == null ? 1.2 : lineH / size,
    );

/// Top-right "Agents" chip: a status dot plus label that opens the
/// [AgentsPopover]. Replaces the old bottom-right System card.
///
/// Has its own overlay anchor rather than `PopoverButton`, whose hit box is
/// a fixed square and cannot hug a labelled chip.
class AgentsChip extends ConsumerStatefulWidget {
  const AgentsChip({super.key});

  @override
  ConsumerState<AgentsChip> createState() => _AgentsChipState();
}

class _AgentsChipState extends ConsumerState<AgentsChip> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusNode(debugLabel: 'agents-popover');

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
    } else {
      _portal.show();
      // Same reason as PopoverButton: Escape must reach the popover, not
      // the canvas shortcut layer that holds focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portal.isShowing) _focus.requestFocus();
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final look = agentsPresentation(ref.watch(mcpViewModelProvider), t);
    final open = _portal.isShowing;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (_) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // Opaque: the dismissing click must not reach the canvas.
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 6),
                child: Focus(
                  focusNode: _focus,
                  onKeyEvent: (_, e) {
                    if (e is KeyDownEvent &&
                        e.logicalKey == LogicalKeyboardKey.escape) {
                      _toggle();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GlassIsland(
                    strong: true,
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SizedBox(
                        width: 236,
                        child: AgentsPopover(
                          // The chip outlives the popover, so the setup
                          // dialog is launched from its context.
                          onSetup: (status) {
                            _toggle();
                            showMcpSetupDialog(context, status);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Tooltip(
          message: 'Agents',
          child: Semantics(
            button: true,
            selected: open,
            label: 'Agents — MCP server ${look.label.toLowerCase()}',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: open ? t.raised : t.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    boxShadow: open ? t.raisedShadow : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: look.dot,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Agents',
                        style: _text(
                          13,
                          FontWeight.w500,
                          open ? t.accentText : t.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The popover body: the MCP server toggle with its live status, and the two
/// things a user needs to actually use it — the endpoint an AI CLI connects
/// to, and a one-click copy of the command that registers it.
///
/// The connection details appear only while the server is genuinely bound.
/// A start that failed (a stale instance still holding the port is the
/// usual cause) shows the reason and a Retry instead, because a connect
/// command pointing at a dead port fails later, elsewhere, and silently.
///
/// Sized by its host (the chip gives it a 236 content width = 270 - 2x1 border - 2x16).
class AgentsPopover extends ConsumerWidget {
  const AgentsPopover({super.key, required this.onSetup});

  final void Function(McpServerStatus status) onSetup;

  Future<void> _copyConnectCommand(
    BuildContext context,
    McpServerStatus status,
  ) async {
    final command = status.connectCommand;
    if (command == null) return;
    // Resolved before the await: the popover is routinely rebuilt while the
    // platform call is in flight.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: command));
    } catch (e) {
      // A platform-channel refusal would otherwise be an unhandled async
      // error with no snackbar — the user taps Copy and nothing happens.
      ExportFeedback.showError(messenger, 'Could not copy: $e');
      return;
    }
    ExportFeedback.showInfo(messenger, 'Copied the connect command');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.fc;
    final status = ref.watch(mcpViewModelProvider);
    final look = agentsPresentation(status, t);
    final vm = ref.read(mcpViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Agents', style: _text(15, FontWeight.w600, t.text)),
              // Flexible + ellipsis: "Failed to start" is the longest pill, so
              // a wider fallback font must clip it rather than overflow.
              Flexible(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: look.pillBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: look.dot,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          look.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(12, FontWeight.w600, look.pillFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SwitchRow(
          label: 'MCP Server',
          value: status.isOn,
          onChanged: (_) => vm.toggle(),
        ),
        _SwitchRow(
          label: 'Animate agent drawing',
          value: ref.watch(animateAgentDrawingProvider),
          onChanged: ref.read(animateAgentDrawingProvider.notifier).set,
        ),
        // Only while the socket is really bound: before that there's no
        // port, and after a failure there's nothing listening on one.
        if (status.isRunning) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: SelectableText(
              status.endpoint!,
              style: _text(
                12,
                FontWeight.w400,
                t.text,
                lineH: 16,
              ).copyWith(fontFamily: AppTypography.geistMonoFamily),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: FcIcons.copy,
                  label: 'Copy connect',
                  tooltip: 'Copy the `claude mcp add` command',
                  onTap: () => _copyConnectCommand(context, status),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: FcIcons.slidersHorizontal,
                  label: 'Setup',
                  tooltip: 'Config for Claude Code, Codex, and Gemini CLI',
                  onTap: () => onSetup(status),
                ),
              ),
            ],
          ),
        ],
        if (status.hasFailed) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.dangerTint,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: FcIconGlyph(
                    FcIcons.circleAlert,
                    size: 16,
                    color: t.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.error!,
                    style: _text(12.5, FontWeight.w400, t.danger, lineH: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: FcIcons.rotateCw,
            label: 'Retry',
            tooltip: 'Try starting the MCP server again',
            onTap: vm.retry,
            labelSize: 13,
            gap: 7,
          ),
        ],
        // The build, where a bug report can read it off the screen — the
        // same string the MCP handshake and `/health` report, so the
        // window and the CLI on the other end can be matched up.
        const SizedBox(height: 12),
        Text(
          'FlowCraft v$appVersion',
          style: _text(12, FontWeight.w400, t.muted),
        ),
      ],
    );
  }
}

/// Label on the left, [FcSwitch] on the right, 32 high.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(13, FontWeight.w500, t.text),
            ),
          ),
          FcSwitch(label: label, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// surface2 button, 34 high, radius 10: icon + label.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.labelSize = 12.5,
    this.gap = 6,
  });

  final FcIcon icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final double labelSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final r = BorderRadius.circular(AppRadius.button);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.surface2,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FcIconGlyph(icon, size: 14, color: t.text),
                SizedBox(width: gap),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: _text(labelSize, FontWeight.w500, t.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
