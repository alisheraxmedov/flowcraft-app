import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  Widget buildNode(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('Node Widgets', () {
    testWidgets('DefaultNodeWidget renders', (tester) async {
      final node = FlowNode(
        id: 'n1',
        type: NodeType.defaultNode,
        label: 'Default Node',
        data: {'field1': 'value1'},
      );
      final controller = FlowController();
      controller.graph.nodes.add(node);

      await tester.pumpWidget(buildNode(DefaultNodeWidget(node: node, controller: controller)));
      
      expect(find.text('Default Node'), findsOneWidget);
      expect(find.text('field1: '), findsOneWidget);
      expect(find.text('value1'), findsOneWidget);
    });

    testWidgets('InputNodeWidget renders', (tester) async {
      final node = FlowNode(
        id: 'n2',
        type: NodeType.input,
        label: 'Input Node',
      );
      final controller = FlowController();
      controller.graph.nodes.add(node);

      await tester.pumpWidget(buildNode(InputNodeWidget(node: node, controller: controller)));
      expect(find.text('Input Node'), findsOneWidget);
    });

    testWidgets('OutputNodeWidget renders', (tester) async {
      final node = FlowNode(
        id: 'n3',
        type: NodeType.output,
        label: 'Output Node',
      );
      final controller = FlowController();
      controller.graph.nodes.add(node);

      await tester.pumpWidget(buildNode(OutputNodeWidget(node: node, controller: controller)));
      expect(find.text('Output Node'), findsOneWidget);
    });

    testWidgets('NodeFieldsPanel correctly renders fields', (tester) async {
      final node = FlowNode(
        id: 'n4',
        data: {'a': 1, 'b': 2},
      );
      
      await tester.pumpWidget(buildNode(NodeFieldsPanel(data: node.data)));
      expect(find.text('a: '), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('b: '), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
