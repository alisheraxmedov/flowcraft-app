import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/viewmodels/mcp_view_model.dart';
import 'package:flowcraft/views/widgets/export_feedback.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/glass/fc_segmented.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';

/// Shows the copy-pasteable config for every supported AI CLI.
Future<void> showMcpSetupDialog(BuildContext context, McpServerStatus status) {
  return showDialog<void>(
    context: context,
    builder: (_) => McpSetupDialog(status: status),
  );
}

TextStyle _text(double size, FontWeight weight, Color color, {double? lineH}) =>
    AppTypography.bodyBase.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: lineH == null ? 1.2 : lineH / size,
    );

enum _Cli { claudeCode, claudeJson, codex, gemini }

/// "Connect an AI CLI" dialog: the app's live endpoint and token, already
/// formatted for each CLI's own config format, one CLI per tab.
///
/// The CLIs deliberately get different shapes rather than one generic
/// snippet — Claude Code and Gemini CLI read JSON but disagree on the URL
/// field name, and Codex reads TOML. A user copying the wrong dialect gets
/// a silent no-op, which is exactly the friction this dialog exists to
/// remove.
class McpSetupDialog extends StatefulWidget {
  const McpSetupDialog({super.key, required this.status});

  final McpServerStatus status;

  @override
  State<McpSetupDialog> createState() => _McpSetupDialogState();
}

class _McpSetupDialogState extends State<McpSetupDialog> {
  _Cli _cli = _Cli.claudeCode;

  /// Hint line and snippet for the active tab.
  (String, String) _content(String endpoint, String token) => switch (_cli) {
    _Cli.claudeCode => (
      'Run once in any terminal:',
      widget.status.connectCommand!,
    ),
    _Cli.claudeJson => (
      'Or add it to .mcp.json / claude_desktop_config.json:',
      _claudeJson(endpoint, token),
    ),
    _Cli.codex => ('In ~/.codex/config.toml:', _codexToml(endpoint, token)),
    _Cli.gemini => (
      'In ~/.gemini/settings.json:',
      _geminiJson(endpoint, token),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final endpoint = widget.status.endpoint;
    final token = widget.status.token;
    final content = endpoint == null || token == null
        ? null
        : _content(endpoint, token);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: GlassIsland(
          strong: true,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    FcIconGlyph(FcIcons.link, size: 20, color: t.accentText),
                    const SizedBox(width: 10),
                    Text(
                      'Connect an AI CLI',
                      style: _text(17, FontWeight.w600, t.text, lineH: 24),
                    ),
                  ],
                ),
                if (content == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'The MCP server is off. Turn it on to see the connection '
                    'details for your AI CLI.',
                    style: _text(13, FontWeight.w400, t.muted, lineH: 19),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  FcSegmented<_Cli>(
                    value: _cli,
                    height: 34,
                    gap: 2,
                    segmentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    inactiveColor: t.text,
                    fontSize: 13,
                    activeWeight: FontWeight.w600,
                    options: const {
                      _Cli.claudeCode: 'Claude Code',
                      _Cli.claudeJson: 'Claude JSON',
                      _Cli.codex: 'Codex CLI',
                      _Cli.gemini: 'Gemini CLI',
                    },
                    onChanged: (v) => setState(() => _cli = v),
                  ),
                  const SizedBox(height: 16),
                  Text(content.$1, style: _text(13, FontWeight.w400, t.muted)),
                  const SizedBox(height: 8),
                  _CodeBlock(snippet: content.$2),
                  const SizedBox(height: 14),
                  Text(
                    "Field names can change between CLI versions — check the "
                    "CLI's MCP docs if a snippet is rejected. The token is "
                    'local to this machine; keep it out of shared repos.',
                    style: _text(12, FontWeight.w400, t.muted, lineH: 18),
                  ),
                ],
                const SizedBox(height: 18),
                // Row, not Align: Align hands its child loose constraints and
                // the button's centred Container would stretch to full width.
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      child: InkWell(
                        key: const ValueKey('mcp_done'),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          child: Text(
                            'Done',
                            style: _text(13, FontWeight.w600, t.onAccent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _claudeJson(String endpoint, String token) =>
    '''
{
  "mcpServers": {
    "flowcraft": {
      "type": "http",
      "url": "$endpoint",
      "headers": { "X-Flowcraft-Token": "$token" }
    }
  }
}''';

String _codexToml(String endpoint, String token) =>
    '''
[mcp_servers.flowcraft]
url = "$endpoint"

[mcp_servers.flowcraft.http_headers]
"X-Flowcraft-Token" = "$token"''';

/// Gemini CLI keys streamable-HTTP servers off `httpUrl`; plain `url` is
/// its (older) SSE transport, which this server doesn't speak.
String _geminiJson(String endpoint, String token) =>
    '''
{
  "mcpServers": {
    "flowcraft": {
      "httpUrl": "$endpoint",
      "headers": { "X-Flowcraft-Token": "$token" }
    }
  }
}''';

/// The snippet in a surface2 well with a raised 32x32 Copy button at its
/// top-right corner.
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
    final t = context.fc;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 52, 14),
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(AppRadius.row),
            border: Border.all(color: t.glassBorder),
          ),
          child: SelectableText(
            snippet,
            style: _text(
              12.5,
              FontWeight.w400,
              t.text,
              lineH: 19,
            ).copyWith(fontFamily: AppTypography.geistMonoFamily),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Tooltip(
            message: 'Copy',
            child: Semantics(
              button: true,
              label: 'Copy',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copy(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.raised,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                        BoxShadow(color: Color(0x0D000000), spreadRadius: 0.5),
                      ],
                    ),
                    child: FcIconGlyph(FcIcons.copy, size: 16, color: t.text),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
