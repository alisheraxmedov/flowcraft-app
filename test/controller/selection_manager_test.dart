import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/controller/selection_manager.dart';

void main() {
  group('SelectionManager', () {
    test('starts with empty selection', () {
      final manager = SelectionManager();
      expect(manager.selectedNodeIds, isEmpty);
      expect(manager.selectedEdgeIds, isEmpty);
      expect(manager.hasSelection, isFalse);
    });

    test('selectNode adds node and clears others', () {
      final manager = SelectionManager();
      manager.selectNode('n1');
      expect(manager.selectedNodeIds.contains('n1'), isTrue);
      expect(manager.hasSelection, isTrue);

      manager.selectNode('n2'); // Clears previous
      expect(manager.selectedNodeIds.contains('n1'), isFalse);
      expect(manager.selectedNodeIds.contains('n2'), isTrue);
    });

    test('toggleNodeSelection allows multi-select', () {
      final manager = SelectionManager();
      manager.selectNode('n1');
      manager.toggleNodeSelection('n2');
      
      expect(manager.selectedNodeIds.length, 2);
      expect(manager.selectedNodeIds.contains('n1'), isTrue);
      expect(manager.selectedNodeIds.contains('n2'), isTrue);

      manager.toggleNodeSelection('n1'); // Should remove n1
      expect(manager.selectedNodeIds.contains('n1'), isFalse);
      expect(manager.selectedNodeIds.contains('n2'), isTrue);
    });

    test('deselectNode/Edge removes specific item', () {
      final manager = SelectionManager();
      manager.selectAll({'n1', 'n2'}, {'e1'});
      
      manager.deselectNode('n1');
      expect(manager.selectedNodeIds.contains('n1'), isFalse);
      expect(manager.selectedNodeIds.contains('n2'), isTrue);

      manager.deselectEdge('e1');
      expect(manager.selectedEdgeIds.isEmpty, isTrue);
    });

    test('clearSelection removes all selected nodes and edges', () {
      final manager = SelectionManager();
      manager.selectNode('n1');
      manager.toggleEdgeSelection('e1');
      
      expect(manager.hasSelection, isTrue);
      
      manager.clearSelection();
      expect(manager.hasSelection, isFalse);
      expect(manager.selectedNodeIds, isEmpty);
      expect(manager.selectedEdgeIds, isEmpty);
    });

    test('selectNodes adds multiple nodes', () {
      final manager = SelectionManager();
      manager.selectNodes({'n1', 'n2'});
      expect(manager.selectedNodeIds.length, 2);
      expect(manager.isNodeSelected('n1'), isTrue);
      expect(manager.isNodeSelected('n2'), isTrue);

      manager.selectNodes({'n3'}, addToSelection: true);
      expect(manager.selectedNodeIds.length, 3);
      expect(manager.isNodeSelected('n3'), isTrue);
    });

    test('selectAll sets nodes and edges simultaneously', () {
      final manager = SelectionManager();
      manager.selectAll({'n1'}, {'e1', 'e2'});
      expect(manager.selectedNodeIds.length, 1);
      expect(manager.selectedEdgeIds.length, 2);
    });
  });
}
