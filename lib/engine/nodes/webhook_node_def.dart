import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Webhook Trigger node — simulates receiving external webhook data.
///
/// Acts as an entry point for workflows that would be triggered
/// by external HTTP webhooks. The payload is configured via params.
class WebhookNodeDef extends NodeDefinition {
  @override
  String get typeId => 'webhook';

  @override
  String get displayName => 'Webhook';

  @override
  String get category => 'Triggers';

  @override
  String get description => 'Receives data from external webhooks';

  @override
  bool get isTrigger => true;

  @override
  List<PortDefinition> get inputs => [];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'body', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'method',
          displayName: 'HTTP Method',
          type: ParamType.select,
          defaultValue: 'POST',
          options: ['GET', 'POST', 'PUT', 'PATCH'],
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'path',
          displayName: 'Path',
          type: ParamType.string,
          defaultValue: '/webhook',
          description: 'The webhook endpoint path',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'testPayload',
          displayName: 'Test Payload',
          type: ParamType.json,
          defaultValue: '{}',
          description: 'Simulated webhook payload for testing',
        ),
        const ParamDefinition(
          name: 'headers',
          displayName: 'Expected Headers',
          type: ParamType.json,
          defaultValue: '{}',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final method = context.getParam<String>('method', 'POST');
    final path = context.getParam<String>('path', '/webhook');
    final payloadRaw = context.params['testPayload'];
    final headersRaw = context.params['headers'];

    final payload = payloadRaw is Map<String, dynamic>
        ? payloadRaw
        : <String, dynamic>{};

    final headers = headersRaw is Map<String, dynamic>
        ? headersRaw
        : <String, dynamic>{};

    return ExecutionResult.success(
      nodeId: context.nodeId,
      outputData: {
        ...payload,
        'method': method,
        'path': path,
        'body': payload,
        'headers': headers,
        '_webhook': true,
      },
    );
  }
}
