import 'package:flowcraft/models/sketch_style.dart';

/// What the style enums are called on screen — the chip wording, kept
/// apart from the enum identifiers the way `ToolShortcuts.labels` is for
/// tools. `FillStyle.crossHatch.name` reads as code; "Cross-hatch" reads
/// as a choice.
class StyleLabels {
  StyleLabels._();

  static const Map<StrokeStyle, String> strokeStyle = {
    StrokeStyle.solid: 'Solid',
    StrokeStyle.dashed: 'Dashed',
    StrokeStyle.dotted: 'Dotted',
  };

  static const Map<FillStyle, String> fillStyle = {
    FillStyle.none: 'None',
    FillStyle.solid: 'Solid',
    FillStyle.hachure: 'Hachure',
    FillStyle.crossHatch: 'Cross-hatch',
  };
}
