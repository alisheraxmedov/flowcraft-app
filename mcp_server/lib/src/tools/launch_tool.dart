import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../launcher.dart';

final launchTool = Tool(
  name: 'flowcraft_launch',
  description:
      'Starts the FlowCraft desktop app if it is not already running, and '
      'waits until it is ready to receive draw commands. Resolves the app '
      'via the FLOWCRAFT_APP_PATH environment variable first, then a few '
      'well-known per-OS install locations.',
  inputSchema: Schema.object(),
);

FutureOr<CallToolResult> handleLaunch(CallToolRequest request) async {
  final ok = await FlowcraftLauncher.launchAndWait();
  if (ok) {
    return CallToolResult(
      content: [TextContent(text: 'FlowCraft app is running and ready.')],
    );
  }
  final path = FlowcraftLauncher.resolveAppPath();
  return CallToolResult(
    isError: true,
    content: [
      TextContent(
        text: path == null
            ? 'Could not find the FlowCraft app on this machine. Set the '
                'FLOWCRAFT_APP_PATH environment variable to its install '
                'path, or start it manually.'
            : 'Found $path but the app did not become reachable in time. '
                'Try starting it manually.',
      ),
    ],
  );
}
