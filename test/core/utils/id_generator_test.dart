import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('IdGenerator', () {
    test('generates unique node ids', () {
      final id1 = IdGenerator.nodeId();
      final id2 = IdGenerator.nodeId();
      expect(id1.startsWith('node_'), isTrue);
      expect(id1, isNot(id2));
    });

    test('generates unique edge ids', () {
      final id1 = IdGenerator.edgeId();
      final id2 = IdGenerator.edgeId();
      expect(id1.startsWith('edge_'), isTrue);
      expect(id1, isNot(id2));
    });

    test('generates unique handle ids', () {
      final id1 = IdGenerator.handleId();
      final id2 = IdGenerator.handleId();
      expect(id1.startsWith('handle_'), isTrue);
      expect(id1, isNot(id2));
    });
  });
}
