import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';

/// Shows the copy-pasteable config for every supported AI CLI.
Future<void> showMcpSetupDialog(
  BuildContext context,
  McpServerStatus status,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => McpSetupDialog(status: status),
  );
}

/// "Connect an AI CLI" dialog: the app's live endpoint and token, already
/// formatted for each CLI's own config format.
///
/// The three CLIs deliberately get three *different* shapes rather than
/// one generic snippet — Claude Code and Gemini CLI read JSON but disagree
/// on the URL field name, and Codex reads TOML. A user copying the wrong
/// dialect gets a silent no-op, which is exactly the friction this dialog
/// exists to remove.
class McpSetupDialog extends StatelessWidget {
  const McpSetupDialog({super.key, required this.status});

  final McpServerStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final endpoint = status.endpoint;
    final token = status.token;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      title: Row(
        children: [
          Icon(Icons.link_rounded, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Connect an AI CLI',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: endpoint == null || token == null
            ? Text(
                'The MCP server is off. Turn it on to see the connection '
                'details for your AI CLI.',
                style: AppTypography.bodyBase.copyWith(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Section(
                      title: 'Claude Code',
                      hint: 'Run once in any terminal:',
                      snippet: status.connectCommand!,
                    ),
                    _Section(
                      title: 'Claude Code / Claude Desktop (JSON)',
                      hint: 'Or add it to .mcp.json / '
                          'claude_desktop_config.json:',
                      snippet: _claudeJson(endpoint, token),
                    ),
                    _Section(
                      title: 'Codex CLI',
                      hint: 'In ~/.codex/config.toml:',
                      snippet: _codexToml(endpoint, token),
                    ),
                    _Section(
                      title: 'Gemini CLI',
                      hint: 'In ~/.gemini/settings.json:',
                      snippet: _geminiJson(endpoint, token),
                    ),
                    Text(
                      'Field names occasionally change between CLI '
                      "versions — check the CLI's own MCP docs if a "
                      'snippet is rejected. The token is local to this '
                      'machine; keep it out of shared repos.',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Done',
            style: AppTypography.bodyBase.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

String _claudeJson(String endpoint, String token) => '''
{
  "mcpServers": {
    "flowcraft": {
      "type": "http",
      "url": "$endpoint",
      "headers": { "X-Flowcraft-Token": "$token" }
    }
  }
}''';

String _codexToml(String endpoint, String token) => '''
[mcp_servers.flowcraft]
url = "$endpoint"

[mcp_servers.flowcraft.http_headers]
"X-Flowcraft-Token" = "$token"''';

/// Gemini CLI keys streamable-HTTP servers off `httpUrl`; plain `url` is
/// its (older) SSE transport, which this server doesn't speak.
String _geminiJson(String endpoint, String token) => '''
{
  "mcpServers": {
    "flowcraft": {
      "httpUrl": "$endpoint",
      "headers": { "X-Flowcraft-Token": "$token" }
    }
  }
}''';

/// One CLI's block: label, one line of context, and a copyable snippet.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.hint,
    required this.snippet,
  });

  final String title;
  final String hint;
  final String snippet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.labelMono.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.toolbarGap),
          _CodeBlock(snippet: snippet),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.snippet});

  final String snippet;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: snippet));
    } catch (e) {
      // Same error path as the export menu's copy — a refused platform
      // call must say so rather than surface as an unhandled async error.
      ExportFeedback.showError(messenger, 'Could not copy: $e');
      return;
    }
    ExportFeedback.showInfo(messenger, 'Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // Horizontal scroll rather than wrapping: a wrapped shell
            // command is easy to mis-copy by hand, and these are long.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                snippet,
                style: AppTypography.labelMono.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: colorScheme.onSurfaceVariant,
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }
}
