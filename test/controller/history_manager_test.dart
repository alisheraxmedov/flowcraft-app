import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/controller/history_manager.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('HistoryManager', () {
    test('initial state has no undo/redo', () {
      final manager = HistoryManager();
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
    });

    test('push saves history and clears redo', () {
      final manager = HistoryManager();
      
      final graph1 = FlowGraph(nodes: [FlowNode(id: '1')], edges: []);
      manager.pushSnapshot(graph1);
      
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
    });

    test('undo retrieves previous state', () {
      final manager = HistoryManager();
      
      final state1 = FlowGraph(nodes: [FlowNode(id: '1')], edges: []);
      final state2 = FlowGraph(nodes: [FlowNode(id: '1'), FlowNode(id: '2')], edges: []);
      
      // Before changing state1 to state2, we push state1
      manager.pushSnapshot(state1);
      
      // Now we are at state2. User presses undo. We pass current state (state2)
      final undoGraph = manager.undo(state2);
      
      expect(undoGraph, isNotNull);
      expect(undoGraph!.nodes.length, 1);
      expect(manager.canRedo, isTrue);
    });

    test('redo retrieves next state', () {
      final manager = HistoryManager();
      
      final state1 = FlowGraph(nodes: [FlowNode(id: '1')], edges: []);
      final state2 = FlowGraph(nodes: [FlowNode(id: '1'), FlowNode(id: '2')], edges: []);
      
      // Before mutating state1
      manager.pushSnapshot(state1); 
      
      // User undoes from state2
      final undoGraph = manager.undo(state2);
      expect(undoGraph!.nodes.length, 1); // Returns state1
      
      // User redoes from state1
      final redoGraph = manager.redo(undoGraph);
      expect(redoGraph, isNotNull);
      expect(redoGraph!.nodes.length, 2); // Returns state2
    });
    
    test('clear removes all history', () {
      final manager = HistoryManager();
      
      final graph1 = FlowGraph(nodes: [], edges: []);
      manager.pushSnapshot(graph1);
      expect(manager.canUndo, isTrue);
      
      manager.clear();
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
    });
  });
}
