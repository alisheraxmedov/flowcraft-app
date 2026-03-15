import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('FlowHandle', () {
    test('equality checks work', () {
      final h1 = FlowHandle(
        id: '1',
        nodeId: 'n1',
        position: HandlePosition.top,
      );
      final h2 = FlowHandle(
        id: '1',
        nodeId: 'n1',
        position: HandlePosition.top,
      );
      final h3 = FlowHandle(
        id: '2',
        nodeId: 'n1',
        position: HandlePosition.top,
      );

      expect(h1, h2);
      expect(h1.hashCode, h2.hashCode);
      expect(h1, isNot(h3));
    });

    test('toJson and fromJson', () {
      final handle = FlowHandle(
        id: 'h1',
        nodeId: 'nodeA',
        position: HandlePosition.left,
        maxConnections: 3,
      );

      final json = handle.toJson();
      final restored = FlowHandle.fromJson(json);

      expect(restored.id, 'h1');
      expect(restored.nodeId, 'nodeA');
      expect(restored.position, HandlePosition.left);
      expect(restored.maxConnections, 3);
    });
    
    test('copyWith works', () {
      final handle = FlowHandle(id: 'h1', nodeId: 'n1', position: HandlePosition.top);
      final copied = handle.copyWith(position: HandlePosition.bottom);
      
      expect(copied.id, 'h1');
      expect(copied.nodeId, 'n1');
      expect(copied.position, HandlePosition.bottom);
    });
  });
}
