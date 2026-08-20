/// FlowCraft — a Miro / Excalidraw-style whiteboard for Flutter.
///
/// Import this library to access all public APIs:
///
/// ```dart
/// import 'package:flowcraft/flowcraft.dart';
/// ```
library;

// Canvas
export 'canvas/grid_painter.dart';
export 'canvas/viewport_transform.dart';
export 'canvas/whiteboard_canvas.dart';

// Core
export 'core/models/flow_viewport.dart';
export 'core/utils/id_generator.dart';

// Sketch — drawing layer (Excalidraw-style)
export 'sketch/models/sketch_element.dart';
export 'sketch/models/sketch_style.dart';
export 'sketch/models/sketch_tool.dart';
export 'sketch/domain/sketch_geometry.dart';
export 'sketch/domain/sketch_hit_test.dart';
export 'sketch/domain/stroke_simplifier.dart';
export 'sketch/state/sketch_controller.dart';
export 'sketch/state/sketch_history.dart';
export 'sketch/rendering/rough_generator.dart';
export 'sketch/rendering/sketch_painter.dart';
export 'sketch/rendering/sketch_preview_painter.dart';
export 'sketch/rendering/sketch_render_cache.dart';
export 'sketch/interactions/sketch_drag_session.dart';
export 'sketch/interactions/sketch_gesture_handler.dart';
export 'sketch/interactions/sketch_interaction_state.dart';
export 'sketch/widgets/sketch_layer.dart';
export 'sketch/widgets/sketch_text_editor.dart';
export 'sketch/widgets/sketch_toolbar.dart';
export 'sketch/widgets/sketch_toolbar_rich.dart';
export 'sketch/serialization/sketch_serializer.dart';
