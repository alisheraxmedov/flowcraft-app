import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Telegram Bot node.
///
/// Sends messages via the Telegram Bot API.
/// Supports text messages, markdown/HTML formatting,
/// silent messages, and reply-to-message.
///
/// Uses [dart:io] HttpClient — no external dependencies.
class TelegramNodeDef extends NodeDefinition {
  @override
  String get typeId => 'telegram';

  @override
  String get displayName => 'Telegram Bot';

  @override
  String get category => 'Integration';

  @override
  String get description => 'Send messages via Telegram Bot API';

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
          name: 'botToken',
          displayName: 'Bot Token',
          type: ParamType.credential,
          description: 'Telegram Bot API token from @BotFather',
        ),
        const ParamDefinition(
          name: 'chatId',
          displayName: 'Chat ID',
          type: ParamType.string,
          description: 'Target chat, group, or channel ID',
        ),
        const ParamDefinition(
          name: 'action',
          displayName: 'Action',
          type: ParamType.select,
          defaultValue: 'sendMessage',
          options: [
            'sendMessage',
            'sendPhoto',
            'sendDocument',
            'getUpdates',
          ],
        ),
        const ParamDefinition(
          name: 'text',
          displayName: 'Message Text',
          type: ParamType.string,
          description: 'Message text. Use {{fieldName}} for interpolation',
        ),
        const ParamDefinition(
          name: 'parseMode',
          displayName: 'Parse Mode',
          type: ParamType.select,
          defaultValue: 'MarkdownV2',
          options: ['', 'MarkdownV2', 'HTML'],
        ),
        const ParamDefinition(
          name: 'photoUrl',
          displayName: 'Photo URL',
          type: ParamType.string,
          description: 'URL of the photo (for sendPhoto action)',
        ),
        const ParamDefinition(
          name: 'documentUrl',
          displayName: 'Document URL',
          type: ParamType.string,
          description: 'URL of the document (for sendDocument action)',
        ),
        const ParamDefinition(
          name: 'caption',
          displayName: 'Caption',
          type: ParamType.string,
          description: 'Caption for photo/document',
        ),
        const ParamDefinition(
          name: 'disableNotification',
          displayName: 'Silent',
          type: ParamType.boolean,
          defaultValue: false,
          description: 'Send message silently',
        ),
        const ParamDefinition(
          name: 'replyToMessageId',
          displayName: 'Reply To Message ID',
          type: ParamType.number,
          description: 'Message ID to reply to',
        ),
      ];

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final botToken = context.getParam<String>('botToken', '').isNotEmpty
        ? context.getParam<String>('botToken', '')
        : context.credentials['telegram_bot_token']?.toString() ?? '';

    if (botToken.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Telegram Bot token is required',
      );
    }

    final chatId = context.getParam<String>('chatId', '');
    final action = context.getParam<String>('action', 'sendMessage');
    var text = context.getParam<String>('text', '');
    var caption = context.getParam<String>('caption', '');
    final parseMode = context.getParam<String>('parseMode', 'MarkdownV2');
    final photoUrl = context.getParam<String>('photoUrl', '');
    final documentUrl = context.getParam<String>('documentUrl', '');
    final silent = context.getParam<bool>('disableNotification', false);
    final replyTo = context.getParam<num>('replyToMessageId', 0).toInt();

    // Interpolate placeholders
    text = _interpolate(text, context.inputData);
    caption = _interpolate(caption, context.inputData);

    if (chatId.isEmpty && action != 'getUpdates') {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Chat ID is required',
      );
    }

    try {
      final body = <String, dynamic>{};

      switch (action) {
        case 'sendMessage':
          if (text.isEmpty) {
            return ExecutionResult.error(
              nodeId: context.nodeId,
              message: 'Message text is required',
            );
          }
          body['chat_id'] = chatId;
          body['text'] = text;
          if (parseMode.isNotEmpty) body['parse_mode'] = parseMode;
          if (silent) body['disable_notification'] = true;
          if (replyTo > 0) body['reply_to_message_id'] = replyTo;
          break;

        case 'sendPhoto':
          if (photoUrl.isEmpty) {
            return ExecutionResult.error(
              nodeId: context.nodeId,
              message: 'Photo URL is required',
            );
          }
          body['chat_id'] = chatId;
          body['photo'] = photoUrl;
          if (caption.isNotEmpty) body['caption'] = caption;
          if (parseMode.isNotEmpty) body['parse_mode'] = parseMode;
          if (silent) body['disable_notification'] = true;
          break;

        case 'sendDocument':
          if (documentUrl.isEmpty) {
            return ExecutionResult.error(
              nodeId: context.nodeId,
              message: 'Document URL is required',
            );
          }
          body['chat_id'] = chatId;
          body['document'] = documentUrl;
          if (caption.isNotEmpty) body['caption'] = caption;
          if (parseMode.isNotEmpty) body['parse_mode'] = parseMode;
          if (silent) body['disable_notification'] = true;
          break;

        case 'getUpdates':
          break;
      }

      final url =
          'https://api.telegram.org/bot$botToken/$action';
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      dynamic parsedBody;
      try {
        parsedBody = jsonDecode(responseBody);
      } catch (_) {
        parsedBody = responseBody;
      }

      if (response.statusCode != 200) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Telegram API error (${response.statusCode}): $responseBody',
        );
      }

      final isOk = parsedBody is Map && parsedBody['ok'] == true;

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'ok': isOk,
          'result': parsedBody is Map ? parsedBody['result'] : parsedBody,
          'action': action,
          'chatId': chatId,
          ...context.inputData,
        },
      );
    } catch (e) {
      debugPrint('FlowCraft Telegram error: $e');
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Telegram request failed: $e',
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
