import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/node_definition_registry.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Minimal concrete NodeDefinition for testing.
class _DummyNode extends NodeDefinition {
  _DummyNode({this.id = 'dummy', this.name = 'Dummy'});
  final String id;
  final String name;

  @override
  String get typeId => id;
  @override
  String get displayName => name;
  @override
  String get category => 'Test';
  @override
  String get description => 'Test node';
  @override
  List<PortDefinition> get inputs => const [];
  @override
  List<PortDefinition> get outputs => const [];
  @override
  List<ParamDefinition> get params => const [];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    return ExecutionResult.success(nodeId: context.nodeId);
  }
}

void main() {
  late NodeDefinitionRegistry registry;

  setUp(() {
    registry = NodeDefinitionRegistry();
  });

  group('NodeDefinitionRegistry', () {
    test('register and retrieve a definition', () {
      final node = _DummyNode();
      registry.register(node);

      expect(registry.getDefinition('dummy'), same(node));
      expect(registry.hasDefinition('dummy'), isTrue);
    });

    test('getDefinition returns null for unregistered type', () {
      expect(registry.getDefinition('unknown'), isNull);
      expect(registry.hasDefinition('unknown'), isFalse);
    });

    test('unregister removes definition', () {
      registry.register(_DummyNode());
      registry.unregister('dummy');

      expect(registry.hasDefinition('dummy'), isFalse);
      expect(registry.getDefinition('dummy'), isNull);
    });

    test('allDefinitions returns all registered', () {
      registry.register(_DummyNode(id: 'a', name: 'A'));
      registry.register(_DummyNode(id: 'b', name: 'B'));

      expect(registry.allDefinitions.length, 2);
    });

    test('registeredTypes returns set of type IDs', () {
      registry.register(_DummyNode(id: 'x'));
      registry.register(_DummyNode(id: 'y'));

      expect(registry.registeredTypes, {'x', 'y'});
    });

    test('definitionsInCategory filters by category', () {
      registry.register(_DummyNode(id: 'a'));
      registry.register(_DummyNode(id: 'b'));

      expect(registry.definitionsInCategory('Test'), hasLength(2));
      expect(registry.definitionsInCategory('Other'), isEmpty);
    });

    test('categories returns unique categories', () {
      registry.register(_DummyNode(id: 'a'));
      registry.register(_DummyNode(id: 'b'));

      expect(registry.categories, {'Test'});
    });

    test('overwriting a type replaces the old definition', () {
      final old = _DummyNode(id: 'x', name: 'Old');
      final replacement = _DummyNode(id: 'x', name: 'New');

      registry.register(old);
      registry.register(replacement);

      expect(registry.getDefinition('x')?.displayName, 'New');
      expect(registry.allDefinitions.length, 1);
    });
  });
}
