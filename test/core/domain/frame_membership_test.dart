import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/frame_membership.dart';
import 'package:flowcraft/models/sketch_element.dart';

void main() {
  final frame = SketchFrame.create(
    id: 'f',
    rect: const Rect.fromLTWH(0, 0, 200, 200),
  );
  SketchRectangle box(String id, Rect r) =>
      SketchRectangle.create(id: id, rect: r);

  test('inside counts, overlapping does not', () {
    final inside = box('in', const Rect.fromLTWH(10, 10, 50, 50));
    final overlapping = box('over', const Rect.fromLTWH(180, 10, 50, 50));
    final outside = box('out', const Rect.fromLTWH(300, 300, 5, 5));
    final members = FrameMembership.members(frame, [
      frame,
      inside,
      overlapping,
      outside,
    ]);
    expect(members.map((e) => e.id), ['in']);
  });

  test('an element exactly filling the frame is a member', () {
    final same = box('same', frame.rect);
    expect(FrameMembership.members(frame, [same]), [same]);
  });
}
