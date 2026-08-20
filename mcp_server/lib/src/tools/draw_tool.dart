import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../bridge_client.dart';

final drawTool = Tool(
  name: 'flowcraft_draw',
  description:
      'Draws shapes on the canvas of the currently running FlowCraft '
      'desktop whiteboard app. Use it to visualize a class model, '
      'architecture diagram, or any other structure analyzed from the '
      "user's codebase — rectangles for classes/modules, text for labels, "
      'arrows for relations. Coordinates are canvas-space pixels; leave '
      'enough spacing between boxes (e.g. 260x120 rectangles, 80px gaps) '
      'so text does not overlap. Call flowcraft_status first if unsure '
      'whether the app is reachable, or flowcraft_launch to start it.',
  inputSchema: Schema.object(
    properties: {
      'mode': Schema.string(
        description:
            '"add" appends to the existing canvas (default). "replace" '
            'clears the canvas first.',
      ),
      'elements': Schema.list(
        description: 'Shapes to draw, in canvas order (first = bottom).',
        items: Schema.object(
          properties: {
            'type': Schema.string(
              description:
                  'rectangle | ellipse | diamond | triangle | sticky | '
                  'text | arrow | line',
            ),
            'x': Schema.num(description: 'Left edge (bounded shapes/text).'),
            'y': Schema.num(description: 'Top edge (bounded shapes/text).'),
            'width': Schema.num(description: 'Box width (bounded shapes).'),
            'height': Schema.num(
              description: 'Box height (bounded shapes).',
            ),
            'fromX': Schema.num(description: 'Start X (arrow/line).'),
            'fromY': Schema.num(description: 'Start Y (arrow/line).'),
            'toX': Schema.num(description: 'End X (arrow/line).'),
            'toY': Schema.num(description: 'End Y (arrow/line).'),
            'text': Schema.string(description: 'Label text, if any.'),
            'fontSize': Schema.num(description: 'Label font size.'),
            'strokeColor': Schema.string(
              description: 'Hex color, e.g. "#1E1E1E". Defaults to black.',
            ),
            'fillColor': Schema.string(
              description: 'Hex color, optional. No fill if omitted.',
            ),
          },
          required: ['type'],
        ),
      ),
    },
    required: ['elements'],
  ),
);

FutureOr<CallToolResult> handleDraw(
  FlowcraftBridgeClient bridge,
  CallToolRequest request,
) async {
  final args = request.arguments ?? const <String, Object?>{};
  final rawElements = (args['elements'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  if (rawElements.isEmpty) {
    return CallToolResult(
      isError: true,
      content: [TextContent(text: 'No elements provided.')],
    );
  }
  final mode = args['mode'] as String? ?? 'add';

  try {
    final result = await bridge.draw(elements: rawElements, mode: mode);
    return CallToolResult(
      content: [
        TextContent(
          text: 'Drew ${rawElements.length} element(s) on FlowCraft '
              '(mode: $mode). Canvas now has ${result['elements']} '
              'element(s) total.',
        ),
      ],
    );
  } on FlowcraftUnreachable catch (e) {
    return CallToolResult(
      isError: true,
      content: [
        TextContent(
          text: '$e\nTip: call flowcraft_launch first, or start the '
              'FlowCraft app manually.',
        ),
      ],
    );
  }
}
