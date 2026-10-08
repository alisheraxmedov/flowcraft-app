/// Topics `flowcraft_guide` can return, in the order `all` prints them.
///
/// Plain text on purpose: an agent reads this once per session to learn the
/// house style, so it costs tokens every time and must stay short. A test
/// (`mcp_guide_test`) fails when a tool is added to `flowcraftMcpTools`
/// without being mentioned here.
const Map<String, String> mcpGuideSections = {
  'tools': '''
TOOLS
- flowcraft_status: is the app reachable, how many elements are on the canvas.
- flowcraft_read: list elements (filters: ids, types, region; paged by limit/offset). Call before update/delete.
- flowcraft_draw: place shapes at explicit coordinates (free placement).
- flowcraft_diagram: nodes + edges, laid out automatically, arrows bound to boxes. Prefer it for any graph.
- flowcraft_update: change fields of existing elements by id.
- flowcraft_delete: remove elements by id.
- flowcraft_clear: remove everything.
- flowcraft_screenshot: PNG of the canvas (or of ids/types/region) so you can check your own drawing.
- flowcraft_guide: this text.
- flowcraft_checkpoint: list/create/restore canvas snapshots; one is taken automatically before every mutating tool.
- flowcraft_project: list/current/open/create/rename saved whiteboards.''',
  'vocabulary': '''
VOCABULARY
Element types: rectangle, ellipse, diamond, triangle, sticky (all x/y/width/height + optional text, fontSize), text (x/y/text/fontSize), line and arrow (fromX/fromY/toX/toY).
Arrows may attach to a shape with fromId/toId (an element id from flowcraft_read, a flowcraft_draw reply or the flowcraft_diagram key map); the tip then follows the shape. "" detaches.
Colours: strokeColor and fillColor are "#RRGGBB" or "#AARRGGBB". flowcraft_diagram nodes take id, label, shape, fillColor, strokeColor; edges take from, to, strokeColor; direction is TB, LR, BT or RL.''',
  'layout': '''
LAYOUT
Use 260x120 boxes with 80px gaps so text does not overlap. Use flowcraft_diagram for graphs (flowcharts, dependencies, state machines, architecture), flowcraft_draw for free placement. After drawing, flowcraft_screenshot to verify, then flowcraft_update to fix single elements instead of clearing and redrawing.''',
  'style': '''
STYLE
Suggested palette, one per diagram: #1E1E1E ink, #E03131 red, #2F9E44 green, #1971C2 blue, #F08C00 orange, #6741D9 violet, #0C8599 teal, #868E96 grey. Light fills (#A5D8FF, #B2F2BB, #FFEC99, #FFC9C9) with a dark stroke read best. Keep labels short; at most 4096 characters per text.''',
  'examples': '''
EXAMPLES
flowcraft_diagram {"nodes":[{"id":"api","label":"API"},{"id":"db","label":"Database","shape":"ellipse"}],"edges":[{"from":"api","to":"db"}],"direction":"LR"}
flowcraft_draw {"elements":[{"type":"rectangle","x":0,"y":0,"width":260,"height":120,"text":"Service"},{"type":"arrow","fromX":260,"fromY":60,"toX":420,"toY":60}]}
flowcraft_read {"types":["rectangle"],"limit":50}
flowcraft_screenshot {"maxSide":1024}
flowcraft_checkpoint {"action":"restore","id":"cp-1"}''',
};

/// Every section, for `topic: all` and for the sync guard in the tests.
final String mcpGuideText = mcpGuideSections.values.join('\n');
