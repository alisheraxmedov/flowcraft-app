import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/param_definition.dart';

void main() {
  group('ParamDefinition', () {
    test('defaults isRequired to false', () {
      const param = ParamDefinition(name: 'test');
      expect(param.isRequired, isFalse);
    });

    test('isRequired can be set to true', () {
      const param = ParamDefinition(name: 'apiKey', isRequired: true);
      expect(param.isRequired, isTrue);
    });

    test('label returns displayName when provided', () {
      const param = ParamDefinition(
        name: 'api_key',
        displayName: 'API Key',
      );
      expect(param.label, 'API Key');
    });

    test('label falls back to name when displayName is null', () {
      const param = ParamDefinition(name: 'apiKey');
      expect(param.label, 'apiKey');
    });

    test('stores all constructor fields correctly', () {
      const param = ParamDefinition(
        name: 'model',
        displayName: 'Model',
        type: ParamType.string,
        defaultValue: 'gpt-4o',
        description: 'Model name',
        options: ['gpt-4o', 'gpt-4o-mini'],
        isRequired: true,
      );
      expect(param.name, 'model');
      expect(param.displayName, 'Model');
      expect(param.type, ParamType.string);
      expect(param.defaultValue, 'gpt-4o');
      expect(param.description, 'Model name');
      expect(param.options, ['gpt-4o', 'gpt-4o-mini']);
      expect(param.isRequired, isTrue);
    });

    test('credential type is distinct', () {
      const param = ParamDefinition(
        name: 'secret',
        type: ParamType.credential,
      );
      expect(param.type, ParamType.credential);
      expect(param.type, isNot(ParamType.string));
    });
  });
}
