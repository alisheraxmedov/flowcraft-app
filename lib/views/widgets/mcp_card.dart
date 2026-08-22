import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/views/widgets/mcp_setup_dialog.dart';

/// How each server state reads on the card, resolved in one place so the
/// badge, the status dot and the status line can never disagree — the
/// exact failure mode this card exists to avoid.
({String badge, String status, Color color}) _presentation(
  McpServerStatus status,
  ColorScheme colorScheme,
) {
  return switch (status.state) {
    McpServerState.running => (
        badge: 'ON',
        status: 'Status: Online',
        color: colorScheme.tertiary,
      ),
    McpServerState.starting => (
        badge: 'STARTING',
        status: 'Status: Starting…',
        color: colorScheme.onSurfaceVariant,
      ),
    McpServerState.off => (
        badge: 'OFF',
        status: 'Status: Offline',
        color: colorScheme.outline,
      ),
    McpServerState.failed => (
        badge: 'ERROR',
        status: 'Status: Failed to start',
        color: colorScheme.error,
      ),
  };
}

/// Bottom-right "System" card: the MCP server toggle, its live status, and
/// the two things a user needs to actually use it — the endpoint an AI CLI
/// connects to, and a one-click copy of the command that registers it.
///
/// The connection details appear only while the server is genuinely bound.
/// A start that failed (a stale instance still holding the port is the
/// usual cause) shows the reason and a Retry instead, because a connect
/// command pointing at a dead port fails later, elsewhere, and silently.
class McpCard extends ConsumerWidget {
  const McpCard({super.key});

  Future<void> _copyConnectCommand(
    BuildContext context,
    McpServerStatus status,
  ) async {
    final command = status.connectCommand;
    if (command == null) return;
    await Clipboard.setData(ClipboardData(text: command));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied the connect command')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(mcpViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final look = _presentation(status, colorScheme);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.panelPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'System',
                style: AppTypography.labelMono.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                look.badge,
                style: AppTypography.caption.copyWith(
                  color: look.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'MCP Server',
                  style: AppTypography.bodyBase.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Switch(
                value: status.isOn,
                onChanged: (_) =>
                    ref.read(mcpViewModelProvider.notifier).toggle(),
                activeThumbColor: colorScheme.tertiary,
                activeTrackColor: colorScheme.tertiaryContainer,
                inactiveThumbColor: colorScheme.onSurfaceVariant,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: look.color,
                ),
              ),
              const SizedBox(width: 8),
              // Expanded + ellipsis: the status line is the longest string
              // on the card, so a wider fallback font must clip it rather
              // than overflow the row.
              Expanded(
                child: Text(
                  look.status,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          // Only while the socket is really bound: before that there's no
          // port, and after a failure there's nothing listening on one.
          if (status.isRunning) ...[
            const SizedBox(height: 12),
            _EndpointRow(endpoint: status.endpoint!),
            const SizedBox(height: AppSpacing.toolbarGap),
            Row(
              children: [
                Expanded(
                  child: _CardAction(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy connect',
                    tooltip: 'Copy the `claude mcp add` command',
                    onTap: () => _copyConnectCommand(context, status),
                  ),
                ),
                const SizedBox(width: AppSpacing.toolbarGap),
                Expanded(
                  child: _CardAction(
                    icon: Icons.tune_rounded,
                    label: 'Setup',
                    tooltip: 'Config for Claude Code, Codex, and Gemini CLI',
                    onTap: () => showMcpSetupDialog(context, status),
                  ),
                ),
              ],
            ),
          ],
          if (status.hasFailed) ...[
            const SizedBox(height: 12),
            _FailureNotice(
              reason: status.error!,
              onRetry: () => ref.read(mcpViewModelProvider.notifier).retry(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The live endpoint, shown in the same mono treatment the toolbar uses
/// for machine-facing values so it reads as something to copy, not prose.
class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.endpoint});

  final String endpoint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.smRadius,
      ),
      child: SelectableText(
        endpoint,
        maxLines: 1,
        style: AppTypography.labelMono.copyWith(
          fontSize: 11,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Why the server isn't up, and the one action that usually fixes it.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reason,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    height: 1.4,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.toolbarGap),
          _CardAction(
            icon: Icons.refresh_rounded,
            label: 'Retry',
            tooltip: 'Try starting the MCP server again',
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.xsRadius,
        child: InkWell(
          borderRadius: AppRadius.xsRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                // Flexible + ellipsis: these buttons split the card's width
                // evenly, so a wider fallback font must degrade the label
                // rather than overflow the row.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurface,
                    ),
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
