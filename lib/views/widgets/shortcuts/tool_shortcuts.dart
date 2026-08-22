import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'package:flowcraft/models/sketch_tool.dart';

/// Which letter picks which tool, and what to call it on screen.
///
/// The keys are Excalidraw's, deliberately and exactly, so anyone arriving
/// from it keeps their muscle memory. Two tools have no Excalidraw
/// equivalent and take the free letter from their own name instead:
/// sticky **n**ote and trian**g**le. None of them uses a modifier, which is
/// what leaves ⌘D free for Duplicate while plain `D` picks the diamond.
class ToolShortcuts {
  ToolShortcuts._();

  static final Map<SketchTool, LogicalKeyboardKey> keys = {
    SketchTool.select: LogicalKeyboardKey.keyV,
    SketchTool.hand: LogicalKeyboardKey.keyH,
    SketchTool.rectangle: LogicalKeyboardKey.keyR,
    SketchTool.ellipse: LogicalKeyboardKey.keyO,
    SketchTool.diamond: LogicalKeyboardKey.keyD,
    SketchTool.triangle: LogicalKeyboardKey.keyG,
    SketchTool.sticky: LogicalKeyboardKey.keyN,
    SketchTool.line: LogicalKeyboardKey.keyL,
    SketchTool.arrow: LogicalKeyboardKey.keyA,
    SketchTool.freedraw: LogicalKeyboardKey.keyP,
    SketchTool.text: LogicalKeyboardKey.keyT,
    SketchTool.eraser: LogicalKeyboardKey.keyE,
  };

  /// Names as the reference sheet prints them — the tool rail's own tooltip
  /// wording, not the enum's.
  static const Map<SketchTool, String> labels = {
    SketchTool.select: 'Select',
    SketchTool.hand: 'Hand (pan)',
    SketchTool.rectangle: 'Rectangle',
    SketchTool.ellipse: 'Ellipse',
    SketchTool.diamond: 'Diamond',
    SketchTool.triangle: 'Triangle',
    SketchTool.sticky: 'Sticky note',
    SketchTool.line: 'Line',
    SketchTool.arrow: 'Arrow',
    SketchTool.freedraw: 'Draw',
    SketchTool.text: 'Text',
    SketchTool.eraser: 'Eraser',
  };
}
