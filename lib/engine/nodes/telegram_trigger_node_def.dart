import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// Telegram Trigger node — starts a workflow from incoming Telegram updates.
///
/// Uses polling (`getUpdates`) to fetch new messages, callback queries,
/// and other Telegram events. The node filters updates by type and
/// outputs structured data for downstream nodes.
///
/// ### Supported update types
/// - `message` — new text messages
/// - `callback_query` — inline keyboard button presses
/// - `edited_message` — edited messages
/// - `channel_post` — new channel posts
/// - `all` — all update types
///
/// ### Usage
/// ```dart
/// final registry = NodeDefinitionRegistry();
/// registry.register(TelegramTriggerNodeDef());
/// ```
class TelegramTriggerNodeDef extends NodeDefinition {
  @override
  String get typeId => 'telegram_trigger';

  @override
  String get displayName => 'Telegram Trigger';

  @override
  String get category => 'Trigger';

  @override
  String get description =>
      'Start workflow from incoming Telegram messages and events';

  @override
  bool get isTrigger => true;

  // ---------------------------------------------------------------------------
  // Ports
  // ---------------------------------------------------------------------------

  @override
  List<PortDefinition> get inputs => const [];

  @override
  List<PortDefinition> get outputs => [
        const PortDefinition(name: 'update', dataType: PortDataType.json),
      ];

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------

  @override
  List<ParamDefinition> get params => [
        const ParamDefinition(
          name: 'botToken',
          displayName: 'Bot Token',
          type: ParamType.credential,
          description: 'Telegram Bot API token from @BotFather',
        ),
        const ParamDefinition(
          name: 'updateType',
          displayName: 'Update Type',
          type: ParamType.select,
          defaultValue: 'message',
          options: [
            'all',
            'message',
            'callback_query',
            'edited_message',
            'channel_post',
          ],
        ),
        const ParamDefinition(
          name: 'pollingTimeout',
          displayName: 'Polling Timeout (seconds)',
          type: ParamType.number,
          defaultValue: 10,
          description: 'Long polling timeout in seconds (0-60)',
        ),
        const ParamDefinition(
          name: 'limit',
          displayName: 'Max Updates',
          type: ParamType.number,
          defaultValue: 10,
          description: 'Maximum number of updates to fetch (1-100)',
        ),
        const ParamDefinition(
          name: 'offset',
          displayName: 'Offset',
          type: ParamType.number,
          defaultValue: 0,
          description: 'Update offset — set to last update_id + 1 '
              'to avoid duplicates. 0 means start from oldest unconfirmed.',
        ),
      ];

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<ExecutionResult> execute(ExecutionContext context) async {
    final botToken = _resolveToken(context);
    if (botToken.isEmpty) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Telegram Bot token is required. '
            'Set it in params or credentials["telegram_bot_token"]',
      );
    }

    final updateType = context.getParam<String>('updateType', 'message');
    final timeout = context.getParam<num>('pollingTimeout', 10).toInt();
    final limit = context.getParam<num>('limit', 10).toInt().clamp(1, 100);
    final offset = context.getParam<num>('offset', 0).toInt();

    try {
      // Build getUpdates query
      final body = <String, dynamic>{
        'timeout': timeout.clamp(0, 60),
        'limit': limit,
      };

      if (offset > 0) body['offset'] = offset;

      // Filter by allowed_updates if not "all"
      if (updateType != 'all') {
        body['allowed_updates'] = [updateType];
      }

      final uri = Uri.parse(
          'https://api.telegram.org/bot$botToken/getUpdates');
      final client = HttpClient();
      client.connectionTimeout =
          Duration(seconds: timeout.clamp(0, 60) + 10);

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message:
              'Telegram API error (${response.statusCode}): $responseBody',
        );
      }

      dynamic parsed;
      try {
        parsed = jsonDecode(responseBody);
      } catch (_) {
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Failed to parse Telegram response',
        );
      }

      final isOk = parsed is Map && parsed['ok'] == true;
      if (!isOk) {
        final desc =
            parsed is Map ? parsed['description'] ?? 'Unknown error' : '';
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Telegram API returned error: $desc',
        );
      }

      final updates = (parsed['result'] as List?) ?? [];

      // Extract the latest update for downstream processing
      if (updates.isEmpty) {
        return ExecutionResult.success(
          nodeId: context.nodeId,
          outputData: {
            'hasUpdates': false,
            'updateCount': 0,
            'updates': <Map<String, dynamic>>[],
            'latestUpdateId': offset,
          },
        );
      }

      // Parse the latest update for convenience
      final latest = updates.last as Map<String, dynamic>;
      final latestId = latest['update_id'] as int? ?? 0;
      final structured = _extractUpdateData(latest, updateType);

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'hasUpdates': true,
          'updateCount': updates.length,
          'updates': updates,
          'latestUpdateId': latestId,
          'nextOffset': latestId + 1,
          ...structured,
        },
      );
    } catch (e) {
      debugPrint('FlowCraft Telegram Trigger error: $e');
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Telegram polling failed: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Token resolution
  // ---------------------------------------------------------------------------

  String _resolveToken(ExecutionContext context) {
    final paramToken = context.getParam<String>('botToken', '');
    if (paramToken.isNotEmpty) return paramToken;
    return context.credentials['telegram_bot_token']?.toString() ?? '';
  }

  // ---------------------------------------------------------------------------
  // Update data extraction
  // ---------------------------------------------------------------------------

  /// Extracts structured data from the latest update for downstream use.
  Map<String, dynamic> _extractUpdateData(
    Map<String, dynamic> update,
    String filterType,
  ) {
    final result = <String, dynamic>{};

    // Message
    final message = update['message'] as Map<String, dynamic>?;
    if (message != null) {
      result['messageText'] = message['text'] ?? '';
      result['messageId'] = message['message_id'];

      final from = message['from'] as Map<String, dynamic>?;
      if (from != null) {
        result['fromUserId'] = from['id'];
        result['fromUsername'] = from['username'] ?? '';
        result['fromFirstName'] = from['first_name'] ?? '';
        result['fromLastName'] = from['last_name'] ?? '';
        result['isBot'] = from['is_bot'] ?? false;
      }

      final chat = message['chat'] as Map<String, dynamic>?;
      if (chat != null) {
        result['chatId'] = chat['id'];
        result['chatType'] = chat['type'] ?? '';
        result['chatTitle'] = chat['title'] ?? '';
      }

      // Check for photos
      final photos = message['photo'] as List?;
      if (photos != null && photos.isNotEmpty) {
        final largest = photos.last as Map<String, dynamic>;
        result['photoFileId'] = largest['file_id'] ?? '';
      }

      // Check for document
      final doc = message['document'] as Map<String, dynamic>?;
      if (doc != null) {
        result['documentFileId'] = doc['file_id'] ?? '';
        result['documentFileName'] = doc['file_name'] ?? '';
      }
    }

    // Callback query
    final callback =
        update['callback_query'] as Map<String, dynamic>?;
    if (callback != null) {
      result['callbackQueryId'] = callback['id'] ?? '';
      result['callbackData'] = callback['data'] ?? '';

      final cbFrom = callback['from'] as Map<String, dynamic>?;
      if (cbFrom != null) {
        result['fromUserId'] = cbFrom['id'];
        result['fromUsername'] = cbFrom['username'] ?? '';
        result['fromFirstName'] = cbFrom['first_name'] ?? '';
      }

      final cbMsg = callback['message'] as Map<String, dynamic>?;
      if (cbMsg != null) {
        result['messageId'] = cbMsg['message_id'];
        final cbChat = cbMsg['chat'] as Map<String, dynamic>?;
        if (cbChat != null) {
          result['chatId'] = cbChat['id'];
        }
      }
    }

    // Channel post
    final channelPost =
        update['channel_post'] as Map<String, dynamic>?;
    if (channelPost != null) {
      result['messageText'] = channelPost['text'] ?? '';
      result['messageId'] = channelPost['message_id'];
      final chat = channelPost['chat'] as Map<String, dynamic>?;
      if (chat != null) {
        result['chatId'] = chat['id'];
        result['chatTitle'] = chat['title'] ?? '';
      }
    }

    // Edited message
    final editedMsg =
        update['edited_message'] as Map<String, dynamic>?;
    if (editedMsg != null) {
      result['messageText'] = editedMsg['text'] ?? '';
      result['messageId'] = editedMsg['message_id'];
      final chat = editedMsg['chat'] as Map<String, dynamic>?;
      if (chat != null) {
        result['chatId'] = chat['id'];
      }
    }

    return result;
  }
}
