import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Google Gemini AI node.
///
/// Sends prompts to Google's Gemini API (generativelanguage.googleapis.com)
/// and returns the model's response. Supports model selection, temperature,
/// system instructions, and safety settings.
///
/// Uses [dart:io] HttpClient — no external dependencies.
class GeminiNodeDef extends NodeDefinition {
  @override
  String get typeId => 'gemini';

  @override
  String get displayName => 'Gemini';

  @override
  String get category => 'AI';

  @override
  String get description => 'Generate content via Google Gemini API';

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
          description: 'Google AI API key',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'model',
          displayName: 'Model',
          type: ParamType.string,
          description: 'Model name (e.g. gemini-2.0-flash, gemini-1.5-pro, etc.)',
          isRequired: true,
        ),
        const ParamDefinition(
          name: 'systemInstruction',
          displayName: 'System Instruction',
          type: ParamType.string,
          defaultValue: '',
          description: 'System-level instruction that guides the model',
        ),
        const ParamDefinition(
          name: 'userMessage',
          displayName: 'User Message',
          type: ParamType.string,
          description: 'The prompt to send. Use {{fieldName}} for input data interpolation',
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
          name: 'maxOutputTokens',
          displayName: 'Max Output Tokens',
          type: ParamType.number,
          defaultValue: 1024,
          description: 'Maximum tokens in the response',
        ),
        const ParamDefinition(
          name: 'topP',
          displayName: 'Top P',
          type: ParamType.number,
          defaultValue: 0.95,
          description: 'Nucleus sampling parameter',
        ),
        const ParamDefinition(
          name: 'topK',
          displayName: 'Top K',
          type: ParamType.number,
          defaultValue: 40,
          description: 'Top-K sampling parameter',
        ),
        const ParamDefinition(
          name: 'safetyLevel',
          displayName: 'Safety Setting',
          type: ParamType.string,
          description: 'Safety threshold (e.g. BLOCK_NONE, BLOCK_MEDIUM_AND_ABOVE, etc.)',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final apiKey = context.getParam<String>('apiKey', '').isNotEmpty
        ? context.getParam<String>('apiKey', '')
        : context.credentials['gemini_api_key']?.toString() ?? '';

    if (apiKey.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Gemini API key is required',
      );
    }

    final model = context.getParam<String>('model', '');
    if (model.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Model name is required',
      );
    }

    final systemInstruction = context.getParam<String>('systemInstruction', '');
    var userMsg = context.getParam<String>('userMessage', '');
    final temperature = context.getParam<num>('temperature', 0.7).toDouble();
    final maxTokens = context.getParam<num>('maxOutputTokens', 1024).toInt();
    final topP = context.getParam<num>('topP', 0.95).toDouble();
    final topK = context.getParam<num>('topK', 40).toInt();
    final safetyLevel = context.getParam<String>('safetyLevel', '');

    // Interpolate {{fieldName}} placeholders
    userMsg = _interpolate(userMsg, context.inputData);

    if (userMsg.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'User message is required',
      );
    }

    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': userMsg},
          ],
        },
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': topP,
        'topK': topK,
      },
    };

    if (safetyLevel.isNotEmpty) {
      body['safetySettings'] = [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': safetyLevel,
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': safetyLevel,
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': safetyLevel,
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': safetyLevel,
        },
      ];
    }

    // Add system instruction if provided
    if (systemInstruction.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 60);

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Gemini API error (${response.statusCode}): $responseBody',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      final content = candidates != null && candidates.isNotEmpty
          ? _extractText(candidates[0])
          : '';
      final usageMetadata = json['usageMetadata'] as Map<String, dynamic>?;

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'content': content,
          'model': model,
          'usage': usageMetadata ?? {},
          'finishReason': candidates?.isNotEmpty == true
              ? candidates![0]['finishReason']
              : null,
          'safetyRatings': candidates?.isNotEmpty == true
              ? candidates![0]['safetyRatings']
              : [],
          'fullResponse': json,
          ...context.inputData,
        },
      );
    } catch (e) {
      debugPrint('FlowCraft Gemini error: $e');
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Gemini request failed: $e',
      );
    }
  }

  String _extractText(Map<String, dynamic> candidate) {
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) return '';
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    return parts.map((p) => p['text']?.toString() ?? '').join();
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
