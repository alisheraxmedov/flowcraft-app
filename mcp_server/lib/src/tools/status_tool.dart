import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../bridge_client.dart';

final statusTool = Tool(
  name: 'flowcraft_status',
  description:
      'Checks whether the FlowCraft desktop whiteboard app is running and '
      'reachable on this machine. Call this before flowcraft_draw if '
      'unsure.',
  inputSchema: Schema.object(),
);

FutureOr<CallToolResult> handleStatus(
  FlowcraftBridgeClient bridge,
  CallToolRequest request,
) async {
  final reachable = await bridge.isReachable();
  return CallToolResult(
    content: [
      TextContent(
        text: reachable
            ? 'FlowCraft app is running and reachable.'
            : 'FlowCraft app is not reachable. Call flowcraft_launch to '
                'try starting it, or start it manually.',
      ),
    ],
  );
}
