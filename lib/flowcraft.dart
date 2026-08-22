/// FlowCraft — a Miro / Excalidraw-style whiteboard for Flutter.
///
/// Import this library to access all public APIs:
///
/// ```dart
/// import 'package:flowcraft/flowcraft.dart';
/// ```
library;

// Models — immutable data
export 'models/flow_project.dart';
export 'models/flow_viewport.dart';
export 'models/sketch_element.dart';
export 'models/sketch_style.dart';
export 'models/sketch_tool.dart';

// ViewModels — app state + Riverpod providers
export 'viewmodels/project_autosave.dart';
export 'viewmodels/projects_state.dart';
export 'viewmodels/projects_view_model.dart';
export 'viewmodels/scene_importer.dart';
export 'viewmodels/sketch_controller.dart';
export 'viewmodels/sketch_history.dart';
export 'viewmodels/theme_view_model.dart';
export 'viewmodels/mcp_view_model.dart';

// Views — screens and reusable widgets
export 'views/splash_view.dart';
export 'views/whiteboard_view.dart';
export 'views/widgets/canvas_shortcuts.dart';
export 'views/widgets/edit_menu_button.dart';
export 'views/widgets/export_feedback.dart';
export 'views/widgets/export_menu_button.dart';
export 'views/widgets/import/import_actions.dart';
export 'views/widgets/import/import_feedback.dart';
export 'views/widgets/import/import_scene_list.dart';
export 'views/widgets/import/import_source_picker.dart';
export 'views/widgets/import_scene_dialog.dart';
export 'views/widgets/mcp_card.dart';
export 'views/widgets/mcp_setup_dialog.dart';
export 'views/widgets/partial_scene_banner.dart';
export 'views/widgets/paste_scene_dialog.dart';
export 'views/widgets/project_dialogs.dart';
export 'views/widgets/project_drawer.dart';
export 'views/widgets/project_tile.dart';
export 'views/widgets/project_title_field.dart';
export 'views/widgets/properties_panel.dart';
export 'views/widgets/shortcuts/canvas_clipboard.dart';
export 'views/widgets/shortcuts/canvas_intents.dart';
export 'views/widgets/shortcuts/canvas_shortcut_manager.dart';
export 'views/widgets/shortcuts/canvas_shortcut_table.dart';
export 'views/widgets/shortcuts/nudge_session.dart';
export 'views/widgets/shortcuts/shortcut_label.dart';
export 'views/widgets/shortcuts/tool_shortcuts.dart';
export 'views/widgets/shortcuts_help_dialog.dart';
export 'views/widgets/sketch_layer.dart';
export 'views/widgets/sketch_text_editor.dart';
export 'views/widgets/toolbar/toolbar.dart';

// Services — external I/O boundary (MCP control server)
export 'services/app_control.dart';
export 'services/canvas_exporter.dart';
export 'services/diagram_spec.dart';
export 'services/export_file_sink.dart';
export 'services/flowcraft_control_server.dart';
export 'services/importable_scene.dart';
export 'services/mcp_tools.dart';
export 'services/project_repository.dart';
export 'services/scene_import_source.dart';

// Core — framework-agnostic infrastructure
export 'core/canvas/grid_painter.dart';
export 'core/canvas/viewport_transform.dart';
export 'core/canvas/whiteboard_canvas.dart';
export 'core/domain/sketch_geometry.dart';
export 'core/domain/sketch_hit_test.dart';
export 'core/domain/stroke_simplifier.dart';
export 'core/domain/text_metrics.dart';
export 'core/interactions/sketch_drag_session.dart';
export 'core/interactions/sketch_gesture_handler.dart';
export 'core/interactions/sketch_interaction_state.dart';
export 'core/interactions/sketch_snapping.dart';
export 'core/rendering/arrow_head.dart';
export 'core/rendering/rough_generator.dart';
export 'core/rendering/sketch_painter.dart';
export 'core/rendering/sketch_preview_painter.dart';
export 'core/rendering/sketch_render_cache.dart';
export 'core/serialization/project_serializer.dart';
export 'core/serialization/sketch_serializer.dart';
export 'core/theme/app_colors.dart';
export 'core/theme/app_radius.dart';
export 'core/theme/app_spacing.dart';
export 'core/theme/app_theme.dart';
export 'core/theme/app_typography.dart';
export 'core/utils/id_generator.dart';
export 'core/utils/relative_time.dart';
