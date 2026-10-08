import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether agent-drawn elements animate in. View-only: it never touches the
/// scene, history or export.
// ponytail: in-memory only, resets to on each launch; persist when a
// settings store exists.
class AnimateAgentDrawing extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final animateAgentDrawingProvider = NotifierProvider<AnimateAgentDrawing, bool>(
  AnimateAgentDrawing.new,
);
