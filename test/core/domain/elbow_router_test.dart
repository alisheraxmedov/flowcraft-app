import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/elbow_router.dart';

void main() {
  test('wide route is horizontal-vertical-horizontal, bending at mid-x', () {
    expect(ElbowRouter.route(const Offset(0, 0), const Offset(100, 40)), [
      const Offset(0, 0),
      const Offset(50, 0),
      const Offset(50, 40),
      const Offset(100, 40),
    ]);
  });

  test('tall route is vertical-horizontal-vertical, bending at mid-y', () {
    expect(ElbowRouter.route(const Offset(0, 0), const Offset(30, 100)), [
      const Offset(0, 0),
      const Offset(0, 50),
      const Offset(30, 50),
      const Offset(30, 100),
    ]);
  });

  test('collinear endpoints need no bend', () {
    expect(
      ElbowRouter.route(const Offset(0, 5), const Offset(80, 5)),
      hasLength(2),
    );
    expect(
      ElbowRouter.route(const Offset(7, 0), const Offset(7, 80)),
      hasLength(2),
    );
  });
}
