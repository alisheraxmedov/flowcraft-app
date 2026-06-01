/// FlowCraft — ReactFlow-style interactive node-based flow diagrams for Flutter.
///
/// Import this library to access all public APIs:
///
/// ```dart
/// import 'package:flowcraft/flowcraft.dart';
/// ```
library;

// Core Enums
export 'core/enums/edge_type.dart';
export 'core/enums/handle_position.dart';
export 'core/enums/node_type.dart';

// Core Models
export 'core/models/edge_style.dart';
export 'core/models/flow_edge.dart';
export 'core/models/flow_graph.dart';
export 'core/models/flow_handle.dart';
export 'core/models/flow_node.dart';
export 'core/models/flow_viewport.dart';

// Core Utils
export 'core/utils/graph_utils.dart';
export 'core/utils/id_generator.dart';
export 'core/utils/math_utils.dart';
export 'core/utils/serializer.dart';

// Controller
export 'controller/flow_controller.dart';
export 'controller/history_manager.dart';
export 'controller/selection_manager.dart';

// Canvas
export 'canvas/canvas_gesture_handler.dart';
export 'canvas/canvas_layer_stack.dart';
export 'canvas/flow_canvas_widget.dart';
export 'canvas/grid_painter.dart';
export 'canvas/viewport_transform.dart';

// Edges
export 'edges/animated_edge_painter.dart';
export 'edges/bezier_edge.dart';
export 'edges/edge_label_widget.dart';
export 'edges/edge_painter.dart';
export 'edges/smooth_step_edge.dart';
export 'edges/step_edge.dart';
export 'edges/straight_edge.dart';

// Nodes
export 'nodes/base_node_widget.dart';
export 'nodes/default_node_widget.dart';
export 'nodes/input_node_widget.dart';
export 'nodes/node_fields_panel.dart';
export 'nodes/node_header.dart';
export 'nodes/node_resize_handle.dart';
export 'nodes/node_type_registry.dart';
export 'nodes/output_node_widget.dart';
export 'nodes/trigger_node_widget.dart';

// Handles
export 'handles/connection_line_painter.dart';
export 'handles/handle_widget.dart';

// Interactions
export 'interactions/connection_handler.dart';
export 'interactions/context_menu_widget.dart';
export 'interactions/node_drag_handler.dart';
export 'interactions/selection_box_painter.dart';

// Overlays
export 'overlays/controls_widget.dart';
export 'overlays/minimap_widget.dart';
export 'overlays/node_properties_panel.dart';
export 'overlays/node_toolbar_widget.dart';

// Theme
export 'theme/default_theme.dart';
export 'theme/flow_theme.dart';

// Engine
export 'engine/execution_context.dart';
export 'engine/execution_engine.dart';
export 'engine/execution_result.dart';
export 'engine/node_definition.dart';
export 'engine/node_definition_registry.dart';
export 'engine/node_status.dart';
export 'engine/param_definition.dart';
export 'engine/port_definition.dart';
export 'engine/workflow_result.dart';
export 'engine/workflow_server.dart';

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

// Engine — Built-in Nodes
export 'engine/nodes/condition_node_def.dart';
export 'engine/nodes/delay_node_def.dart';
export 'engine/nodes/error_handler_node_def.dart';
export 'engine/nodes/gemini_node_def.dart';
export 'engine/nodes/http_request_node_def.dart';
export 'engine/nodes/loop_node_def.dart';
export 'engine/nodes/merge_node_def.dart';
export 'engine/nodes/openai_node_def.dart';
export 'engine/nodes/output_node_def.dart';
export 'engine/nodes/telegram_node_def.dart';
export 'engine/nodes/telegram_trigger_node_def.dart';
export 'engine/nodes/transform_node_def.dart';
export 'engine/nodes/trigger_node_def.dart';
export 'engine/nodes/variable_node_def.dart';
export 'engine/nodes/webhook_node_def.dart';
