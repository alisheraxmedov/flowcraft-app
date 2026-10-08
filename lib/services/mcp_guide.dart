import 'package:flowcraft/models/icon_catalog.dart';

/// Topics `flowcraft_guide` can return, in the order `all` prints them.
///
/// Plain text on purpose: an agent reads this once per session to learn the
/// house style, so it costs tokens every time and must stay short. A test
/// (`mcp_guide_test`) fails when a tool is added to `flowcraftMcpTools`
/// without being mentioned here.
final Map<String, String> mcpGuideSections = {
  'tools': '''
TOOLS
- flowcraft_status: is the app reachable, how many elements are on the canvas.
- flowcraft_read: list elements (filters: ids, types, frame, region; paged by limit/offset). Call before update/delete. Image bytes are left out unless includeImageData is true.
- flowcraft_draw: place shapes at explicit coordinates (free placement).
- flowcraft_diagram: nodes + edges (+ frames, ER entities), laid out automatically, arrows bound to boxes. Prefer it for any graph.
- flowcraft_import: Mermaid / DBML / Excalidraw / FlowCraft-JSON text to canvas; errors carry line numbers and leave the canvas untouched.
- flowcraft_update: change fields of existing elements by id.
- flowcraft_delete: remove elements by id.
- flowcraft_clear: remove everything.
- flowcraft_screenshot: PNG of the canvas (or of ids/types/frame/region) so you can check your own drawing.
- flowcraft_export: png / svg / json of the canvas or a selection, inline or written to an absolute path (extension must match; overwrite: true to replace).
- flowcraft_guide: this text.
- flowcraft_checkpoint: list/create/restore canvas snapshots; one is taken automatically before every mutating tool.
- flowcraft_project: list/current/open/create/rename saved whiteboards.''',
  'vocabulary':
      '''
VOCABULARY
Element types: rectangle, ellipse, diamond, triangle, sticky (all x/y/width/height + optional text, fontSize), text (x/y/text/fontSize), line and arrow (fromX/fromY/toX/toY).
Arrows may attach to a shape with fromId/toId (an element id from flowcraft_read, a flowcraft_draw reply or the flowcraft_diagram key map); the tip then follows the shape. "" detaches. "elbow": true routes an arrow with right-angle bends.
frame: x/y/width/height/name. A labelled container drawn behind the elements wholly inside it; the "frame" filter of read/screenshot/export (id or name) selects it with its contents.
icon: x/y/width/height + name, one of ${iconCatalog.keys.join(', ')}. Unknown names are rejected.
image: x/y + path (absolute or ~/, .png .jpg .jpeg .webp .gif) or dataUrl ("data:image/png;base64,..."), max 4 MiB each. Omit width/height for the natural size; give one to keep the aspect ratio.
entity (ER table): x/y/width/name/attributes:[{"name":"id","type":"int","pk":true,"fk":false}]. Height follows the rows. Connect entities with arrows: startHead/endHead is one, many, zeroOrOne, zeroOrMany or oneOrMany (arrow/none otherwise); fromAttribute/toAttribute (with fromId/toId) bind the end to that row.
Text style: fontFamily "sans" (default) or "mono", bold, and on type "text" align left/center/right.
Colours: strokeColor and fillColor are "#RRGGBB" or "#AARRGGBB". flowcraft_diagram nodes take id, label, shape, fillColor, strokeColor, attributes (makes an entity); edges take from, to, strokeColor, fromCardinality/toCardinality, fromAttribute/toAttribute; frames take name and members (node ids); direction is TB, LR, BT or RL; connectors is straight or elbow.''',
  'layout': '''
LAYOUT
Use 260x120 boxes with 80px gaps so text does not overlap. Use flowcraft_diagram for graphs (flowcharts, dependencies, state machines, architecture), flowcraft_import when you already have Mermaid or DBML text, flowcraft_draw for free placement. New content lands beside what is there (mode "add") and the view scrolls to it. After drawing, flowcraft_screenshot to verify, then flowcraft_update to fix single elements instead of clearing and redrawing.''',
  'style': '''
STYLE
Suggested palette, one per diagram: #1E1E1E ink, #E03131 red, #2F9E44 green, #1971C2 blue, #F08C00 orange, #6741D9 violet, #0C8599 teal, #868E96 grey. Light fills (#A5D8FF, #B2F2BB, #FFEC99, #FFC9C9) with a dark stroke read best. Keep labels short; at most 4096 characters per text.''',
  'examples': '''
EXAMPLES
flowcraft_diagram {"nodes":[{"id":"api","label":"API"},{"id":"db","label":"Database","shape":"ellipse"}],"edges":[{"from":"api","to":"db"}],"direction":"LR","frames":[{"name":"Backend","members":["api","db"]}]}
flowcraft_draw {"elements":[{"type":"rectangle","x":0,"y":0,"width":260,"height":120,"text":"Service"},{"type":"arrow","fromX":260,"fromY":60,"toX":420,"toY":60,"elbow":true}]}
flowcraft_draw {"elements":[{"type":"entity","x":0,"y":0,"width":240,"name":"users","attributes":[{"name":"id","type":"int","pk":true}]},{"type":"icon","x":400,"y":0,"width":64,"height":64,"name":"database"},{"type":"image","x":400,"y":120,"path":"~/Pictures/logo.png"}]}
flowcraft_import {"text":"flowchart LR\\n  a[Client] --> b{Auth?}\\n  b --> c((DB))\\n  subgraph Backend\\n    b\\n    c\\n  end"}
flowcraft_import {"text":"erDiagram\\n  USER ||--o{ ORDER : places\\n  USER {\\n    int id PK\\n  }\\n  ORDER {\\n    int id PK\\n    int user_id FK\\n  }"}
flowcraft_import {"text":"Table users {\\n  id int [pk]\\n}\\nTable posts {\\n  id int [pk]\\n  user_id int [ref: > users.id]\\n}"}
flowcraft_import {"text":"<contents of a .excalidraw file>","mode":"replace"}
flowcraft_read {"types":["rectangle"],"limit":50}
flowcraft_screenshot {"maxSide":1024,"frame":"Backend"}
flowcraft_export {"format":"svg","path":"~/Documents/diagram.svg","overwrite":true}
flowcraft_checkpoint {"action":"restore","id":"cp-1"}''',
};

/// Every section, for `topic: all` and for the sync guard in the tests.
final String mcpGuideText = mcpGuideSections.values.join('\n');
