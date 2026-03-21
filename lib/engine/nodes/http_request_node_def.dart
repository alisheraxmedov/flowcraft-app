import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// HTTP Request node — makes HTTP calls to external APIs.
///
/// Uses [dart:io] HttpClient so no external dependencies are needed.
class HttpRequestNodeDef extends NodeDefinition {
  @override
  String get typeId => 'http_request';

  @override
  String get displayName => 'HTTP Request';

  @override
  String get category => 'Core';

  @override
  String get description => 'Makes HTTP requests to external APIs';

  @override
  List<PortDefinition> get inputs => [
        const PortDefinition(
          name: 'data',
          dataType: PortDataType.json,
          required: false,
        ),
      ];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'response', dataType: PortDataType.json),
      ];

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'url',
          displayName: 'URL',
          type: ParamType.string,
          description: 'The URL to send the request to',
        ),
        const ParamDefinition(
          name: 'method',
          displayName: 'Method',
          type: ParamType.select,
          defaultValue: 'GET',
          options: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
        ),
        const ParamDefinition(
          name: 'headers',
          displayName: 'Headers',
          type: ParamType.json,
          defaultValue: '{}',
        ),
        const ParamDefinition(
          name: 'body',
          displayName: 'Body',
          type: ParamType.json,
          defaultValue: '{}',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final url = context.getParam<String>('url', '');
    final method = context.getParam<String>('method', 'GET').toUpperCase();

    if (url.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'URL is required',
      );
    }

    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final headersRaw = context.params['headers'];
      final headers = <String, String>{};
      if (headersRaw is Map) {
        for (final e in headersRaw.entries) {
          headers[e.key.toString()] = e.value.toString();
        }
      }

      final bodyRaw = context.params['body'];
      final body = bodyRaw is Map
          ? jsonEncode(bodyRaw)
          : (bodyRaw is String ? bodyRaw : '');

      HttpClientRequest request;

      switch (method) {
        case 'POST':
          request = await client.postUrl(uri);
          break;
        case 'PUT':
          request = await client.putUrl(uri);
          break;
        case 'PATCH':
          request = await client.patchUrl(uri);
          break;
        case 'DELETE':
          request = await client.deleteUrl(uri);
          break;
        default:
          request = await client.getUrl(uri);
      }

      headers.forEach((key, value) => request.headers.set(key, value));

      if (method != 'GET' && method != 'DELETE' && body.isNotEmpty) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      dynamic parsedBody;
      try {
        parsedBody = jsonDecode(responseBody);
      } catch (_) {
        parsedBody = responseBody;
      }

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'statusCode': response.statusCode,
          'body': parsedBody,
          'headers': responseHeaders,
        },
      );
    } catch (e) {
      debugPrint('FlowCraft HTTP error: $e');
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'HTTP request failed: $e',
      );
    }
  }
}
