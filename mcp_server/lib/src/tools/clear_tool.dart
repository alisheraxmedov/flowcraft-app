import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../bridge_client.dart';

final clearTool = Tool(
  name: 'flowcraft_clear',
  description: 'Removes every shape from the FlowCraft canvas.',
  inputSchema: Schema.object(),
);

FutureOr<CallToolResult> handleClear(
  FlowcraftBridgeClient bridge,
  CallToolRequest request,
) async {
  try {
    await bridge.clear();
    return CallToolResult(content: [TextContent(text: 'Canvas cleared.')]);
  } on FlowcraftUnreachable catch (e) {
    return CallToolResult(isError: true, content: [TextContent(text: '$e')]);
  }
}
