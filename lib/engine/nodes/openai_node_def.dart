import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// OpenAI Chat Completion node.
///
/// Sends messages to OpenAI's Chat Completions API and returns
/// the assistant's response. Supports model selection, temperature,
/// system prompt, and all standard parameters.
///
/// Uses [dart:io] HttpClient — no external dependencies.
class OpenAiNodeDef extends NodeDefinition {
  @override
  String get typeId => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  String get category => 'AI';

  @override
  String get description => 'Chat completion via OpenAI API';

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
          name: 'apiKey',
          displayName: 'API Key',
          type: ParamType.credential,
          description: 'OpenAI API key (sk-...)',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'model',
          displayName: 'Model',
          type: ParamType.string,
          description: 'Model name (e.g. gpt-4o, gpt-4o-mini, o1, etc.)',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'systemMessage',
          displayName: 'System Message',
          type: ParamType.string,
          description: 'System prompt that sets the AI behavior',
        ),
        const ParamDefinition(
          name: 'userMessage',
          displayName: 'User Message',
          type: ParamType.string,
          description: 'The user message to send. Use {{fieldName}} for input data interpolation',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'temperature',
          displayName: 'Temperature',
          type: ParamType.number,
          defaultValue: 0.7,
          description: 'Controls randomness (0.0 = focused, 2.0 = creative)',
        ),
        const ParamDefinition(
          name: 'maxTokens',
          displayName: 'Max Tokens',
          type: ParamType.number,
          defaultValue: 1024,
          description: 'Maximum tokens in the response',
        ),
        const ParamDefinition(
          name: 'topP',
          displayName: 'Top P',
          type: ParamType.number,
          defaultValue: 1.0,
          description: 'Nucleus sampling parameter',
        ),
        const ParamDefinition(
          name: 'frequencyPenalty',
          displayName: 'Frequency Penalty',
          type: ParamType.number,
          defaultValue: 0.0,
          description: 'Reduce repetition (-2.0 to 2.0)',
        ),
        const ParamDefinition(
          name: 'presencePenalty',
          displayName: 'Presence Penalty',
          type: ParamType.number,
          defaultValue: 0.0,
          description: 'Encourage new topics (-2.0 to 2.0)',
        ),
        const ParamDefinition(
          name: 'baseUrl',
          displayName: 'Base URL',
          type: ParamType.string,
          defaultValue: 'https://api.openai.com/v1',
          description: 'API base URL (change for proxies or Azure)',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final apiKey = context.getParam<String>('apiKey', '') .isNotEmpty
        ? context.getParam<String>('apiKey', '')
        : context.credentials['openai_api_key']?.toString() ?? '';

    if (apiKey.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'OpenAI API key is required',
      );
    }

    final model = context.getParam<String>('model', '');
    if (model.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Model name is required',
      );
    }

    final systemMsg = context.getParam<String>('systemMessage', '');
    var userMsg = context.getParam<String>('userMessage', '');
    final temperature = context.getParam<num>('temperature', 0.7).toDouble();
    final maxTokens = context.getParam<num>('maxTokens', 1024).toInt();
    final topP = context.getParam<num>('topP', 1.0).toDouble();
    final freqPenalty = context.getParam<num>('frequencyPenalty', 0.0).toDouble();
    final presPenalty = context.getParam<num>('presencePenalty', 0.0).toDouble();
    final baseUrl = context.getParam<String>('baseUrl', 'https://api.openai.com/v1');

    // Interpolate {{fieldName}} placeholders with input data
    userMsg = _interpolate(userMsg, context.inputData);

    if (userMsg.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'User message is required',
      );
    }

    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemMsg},
        {'role': 'user', 'content': userMsg},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': topP,
      'frequency_penalty': freqPenalty,
      'presence_penalty': presPenalty,
    };

    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 60);

      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'OpenAI API error (${response.statusCode}): $responseBody',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      final content = choices != null && choices.isNotEmpty
          ? (choices[0]['message']?['content'] ?? '')
          : '';
      final usage = json['usage'] as Map<String, dynamic>?;

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'content': content,
          'model': json['model'] ?? model,
          'usage': usage ?? {},
          'finishReason': choices?.isNotEmpty == true
              ? choices![0]['finish_reason']
              : null,
          'fullResponse': json,
          ...context.inputData,
        },
      );
    } catch (e) {
      debugPrint('FlowCraft OpenAI error: $e');
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'OpenAI request failed: $e',
      );
    }
  }

  String _interpolate(String template, Map<String, dynamic> data) {
    return template.replaceAllMapped(
      RegExp(r'\{\{(\w+)\}\}'),
      (match) {
        final key = match.group(1)!;
        return data[key]?.toString() ?? '{{$key}}';
      },
    );
  }
}
