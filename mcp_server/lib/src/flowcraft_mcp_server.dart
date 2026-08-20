import 'package:dart_mcp/server.dart';

import 'bridge_client.dart';
import 'tools/clear_tool.dart';
import 'tools/draw_tool.dart';
import 'tools/launch_tool.dart';
import 'tools/status_tool.dart';

/// MCP server exposing FlowCraft's drawing surface as tools.
///
/// Runs over stdio (the only transport `package:dart_mcp` currently
/// supports) and is spawned by the AI CLI (Claude Code, Codex, Gemini
/// CLI, ...) as a child process. It never touches the FlowCraft app's
/// state directly — every tool call is forwarded over HTTP to the app's
/// own local control server via [FlowcraftBridgeClient].
base class FlowcraftMcpServer extends MCPServer with ToolsSupport {
  FlowcraftMcpServer(super.channel, {FlowcraftBridgeClient? bridge})
      : _bridge = bridge ?? FlowcraftBridgeClient(),
        super.fromStreamChannel(
          implementation: Implementation(
            name: 'flowcraft-mcp-server',
            version: '0.1.0',
          ),
          instructions:
              'Draws diagrams live on the FlowCraft desktop whiteboard '
              'app. Call flowcraft_status to check connectivity, '
              'flowcraft_launch to start the app if needed, then '
              'flowcraft_draw with shapes (rectangles for classes/'
              'modules, arrows for relations) to render the diagram you '
              'have analyzed.',
        ) {
    registerTool(statusTool, (r) => handleStatus(_bridge, r));
    registerTool(launchTool, handleLaunch);
    registerTool(drawTool, (r) => handleDraw(_bridge, r));
    registerTool(clearTool, (r) => handleClear(_bridge, r));
  }

  final FlowcraftBridgeClient _bridge;
}
