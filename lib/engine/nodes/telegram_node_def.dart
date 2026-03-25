import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/execution_result.dart';
import 'package:flowcraft/engine/node_definition.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

/// All supported Telegram Bot API actions.
///
/// Each action maps directly to a Telegram Bot API method.
enum TelegramAction {
  sendMessage,
  sendPhoto,
  sendDocument,
  sendVideo,
  sendLocation,
  sendSticker,
  sendChatAction,
  editMessageText,
  deleteMessage,
  forwardMessage,
  copyMessage,
  pinChatMessage,
  unpinChatMessage,
  answerCallbackQuery,
  getMe,
  getChat,
  getChatMember,
  getUpdates,
}

/// Comprehensive Telegram Bot action node.
///
/// Supports 18 Telegram Bot API methods including messaging,
/// media, moderation, inline keyboards, and bot info queries.
///
/// Uses [dart:io] HttpClient — no external dependencies.
///
/// ### Usage
/// ```dart
/// final registry = NodeDefinitionRegistry();
/// registry.register(TelegramNodeDef());
/// ```
class TelegramNodeDef extends NodeDefinition {
  @override
  String get typeId => 'telegram';

  @override
  String get displayName => 'Telegram Bot';

  @override
  String get category => 'Integration';

  @override
  String get description =>
      'Interact with Telegram Bot API — send messages, '
      'media, edit, delete, moderate, and query bot info';

  // ---------------------------------------------------------------------------
  // Ports
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------

  /// All available action names.
  static const List<String> actionOptions = [
    'sendMessage',
    'sendPhoto',
    'sendDocument',
    'sendVideo',
    'sendLocation',
    'sendSticker',
    'sendChatAction',
    'editMessageText',
    'deleteMessage',
    'forwardMessage',
    'copyMessage',
    'pinChatMessage',
    'unpinChatMessage',
    'answerCallbackQuery',
    'getMe',
    'getChat',
    'getChatMember',
    'getUpdates',
  ];

  /// Actions that do not require a `chatId` parameter.
  static const Set<String> _noChatIdActions = {
    'getMe',
    'getUpdates',
    'answerCallbackQuery',
  };

  @override
  List<ParamDefinition> get params => [
        // ── Credentials ──
        const ParamDefinition(
          name: 'botToken',
          displayName: 'Bot Token',
          type: ParamType.credential,
          description: 'Telegram Bot API token from @BotFather',
        ),

        // ── Target ──
        const ParamDefinition(
          name: 'chatId',
          displayName: 'Chat ID',
          type: ParamType.string,
          description: 'Target chat, group, or channel ID',
        ),

        // ── Action selector ──
        const ParamDefinition(
          name: 'action',
          displayName: 'Action',
          type: ParamType.select,
          defaultValue: 'sendMessage',
          options: actionOptions,
        ),

        // ── Text & formatting ──
        const ParamDefinition(
          name: 'text',
          displayName: 'Message Text',
          type: ParamType.string,
          description: 'Message text. Supports {{fieldName}} interpolation',
        ),
        const ParamDefinition(
          name: 'parseMode',
          displayName: 'Parse Mode',
          type: ParamType.select,
          defaultValue: 'MarkdownV2',
          options: ['', 'MarkdownV2', 'HTML'],
        ),

        // ── Media ──
        const ParamDefinition(
          name: 'photoUrl',
          displayName: 'Photo URL',
          type: ParamType.string,
          description: 'URL or file_id of the photo',
        ),
        const ParamDefinition(
          name: 'documentUrl',
          displayName: 'Document URL',
          type: ParamType.string,
          description: 'URL or file_id of the document',
        ),
        const ParamDefinition(
          name: 'videoUrl',
          displayName: 'Video URL',
          type: ParamType.string,
          description: 'URL or file_id of the video',
        ),
        const ParamDefinition(
          name: 'stickerFileId',
          displayName: 'Sticker File ID',
          type: ParamType.string,
          description: 'File ID of the sticker',
        ),
        const ParamDefinition(
          name: 'caption',
          displayName: 'Caption',
          type: ParamType.string,
          description: 'Caption for photo/document/video. '
              'Supports {{fieldName}} interpolation',
        ),

        // ── Location ──
        const ParamDefinition(
          name: 'latitude',
          displayName: 'Latitude',
          type: ParamType.number,
          description: 'Latitude for sendLocation',
        ),
        const ParamDefinition(
          name: 'longitude',
          displayName: 'Longitude',
          type: ParamType.number,
          description: 'Longitude for sendLocation',
        ),

        // ── Message ID (edit/delete/pin/forward) ──
        const ParamDefinition(
          name: 'messageId',
          displayName: 'Message ID',
          type: ParamType.number,
          description: 'Target message ID for edit/delete/pin/forward',
        ),

        // ── Chat action (typing indicator) ──
        const ParamDefinition(
          name: 'chatAction',
          displayName: 'Chat Action',
          type: ParamType.select,
          defaultValue: 'typing',
          options: [
            'typing',
            'upload_photo',
            'upload_video',
            'upload_document',
            'upload_voice',
            'record_video',
            'record_voice',
            'find_location',
            'choose_sticker',
          ],
        ),

        // ── Forward / Copy ──
        const ParamDefinition(
          name: 'fromChatId',
          displayName: 'From Chat ID',
          type: ParamType.string,
          description: 'Source chat ID for forwardMessage/copyMessage',
        ),

        // ── Callback query ──
        const ParamDefinition(
          name: 'callbackQueryId',
          displayName: 'Callback Query ID',
          type: ParamType.string,
          description: 'Callback query ID for answerCallbackQuery',
        ),
        const ParamDefinition(
          name: 'showAlert',
          displayName: 'Show Alert',
          type: ParamType.boolean,
          defaultValue: false,
          description: 'Show popup alert instead of toast',
        ),

        // ── getChatMember ──
        const ParamDefinition(
          name: 'userId',
          displayName: 'User ID',
          type: ParamType.number,
          description: 'User ID for getChatMember',
        ),

        // ── Inline keyboard (reply_markup) ──
        const ParamDefinition(
          name: 'replyMarkup',
          displayName: 'Reply Markup (JSON)',
          type: ParamType.json,
          description: 'Inline keyboard JSON. Example: '
              '{"inline_keyboard":[[{"text":"Yes","callback_data":"yes"},'
              '{"text":"No","callback_data":"no"}]]}',
        ),

        // ── Behavior flags ──
        const ParamDefinition(
          name: 'disableNotification',
          displayName: 'Silent',
          type: ParamType.boolean,
          defaultValue: false,
          description: 'Send message silently',
        ),
        const ParamDefinition(
          name: 'protectContent',
          displayName: 'Protect Content',
          type: ParamType.boolean,
          defaultValue: false,
          description: 'Prevent forwarding and saving',
        ),
        const ParamDefinition(
          name: 'disableWebPagePreview',
          displayName: 'Disable Link Preview',
          type: ParamType.boolean,
          defaultValue: false,
          description: 'Disable automatic link preview',
        ),
        const ParamDefinition(
          name: 'replyToMessageId',
          displayName: 'Reply To Message ID',
          type: ParamType.number,
          description: 'Message ID to reply to',
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

    final action = context.getParam<String>('action', 'sendMessage');
    final chatId = context.getParam<String>('chatId', '');

    // Validate chatId for actions that require it
    if (chatId.isEmpty && !_noChatIdActions.contains(action)) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: 'Chat ID is required for "$action"',
      );
    }

    // Build action-specific request body
    final bodyResult = _buildBody(action, chatId, context);
    if (bodyResult.error != null) {
      return ExecutionResult.error(
        nodeId: context.nodeId,
        message: bodyResult.error!,
      );
    }

    // Determine API method name
    final apiMethod = _apiMethod(action);

    // Call Telegram API
    return _callApi(
      botToken: botToken,
      method: apiMethod,
      body: bodyResult.body,
      action: action,
      chatId: chatId,
      context: context,
    );
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
  // API method mapping
  // ---------------------------------------------------------------------------

  String _apiMethod(String action) {
    // Most actions map directly; some need adjustment
    switch (action) {
      case 'pinMessage':
      case 'pinChatMessage':
        return 'pinChatMessage';
      case 'unpinMessage':
      case 'unpinChatMessage':
        return 'unpinChatMessage';
      default:
        return action;
    }
  }

  // ---------------------------------------------------------------------------
  // Body builder — one case per action
  // ---------------------------------------------------------------------------

  _BodyResult _buildBody(
    String action,
    String chatId,
    ExecutionContext context,
  ) {
    final body = <String, dynamic>{};

    var text = context.getParam<String>('text', '');
    var caption = context.getParam<String>('caption', '');
    final parseMode = context.getParam<String>('parseMode', 'MarkdownV2');
    final silent = context.getParam<bool>('disableNotification', false);
    final protectContent = context.getParam<bool>('protectContent', false);
    final replyTo = context.getParam<num>('replyToMessageId', 0).toInt();
    final disableLinkPreview =
        context.getParam<bool>('disableWebPagePreview', false);

    // Interpolate templates
    text = _interpolate(text, context.inputData);
    caption = _interpolate(caption, context.inputData);

    // Common helpers
    void addChatId() => body['chat_id'] = chatId;
    void addParseMode() {
      if (parseMode.isNotEmpty) body['parse_mode'] = parseMode;
    }

    void addSilent() {
      if (silent) body['disable_notification'] = true;
    }

    void addProtect() {
      if (protectContent) body['protect_content'] = true;
    }

    void addReplyTo() {
      if (replyTo > 0) body['reply_to_message_id'] = replyTo;
    }

    void addReplyMarkup() {
      final markup = context.getParam<dynamic>('replyMarkup', null);
      if (markup != null) {
        if (markup is String && markup.trim().isNotEmpty) {
          try {
            body['reply_markup'] = jsonDecode(markup);
          } catch (_) {
            // Silently skip malformed JSON
          }
        } else if (markup is Map) {
          body['reply_markup'] = markup;
        }
      }
    }

    switch (action) {
      // ── Messaging ──
      case 'sendMessage':
        if (text.isEmpty) {
          return _BodyResult.err('Message text is required for sendMessage');
        }
        addChatId();
        body['text'] = text;
        addParseMode();
        addSilent();
        addProtect();
        addReplyTo();
        addReplyMarkup();
        if (disableLinkPreview) body['disable_web_page_preview'] = true;

      // ── Media ──
      case 'sendPhoto':
        final url = context.getParam<String>('photoUrl', '');
        if (url.isEmpty) {
          return _BodyResult.err('Photo URL is required for sendPhoto');
        }
        addChatId();
        body['photo'] = url;
        if (caption.isNotEmpty) body['caption'] = caption;
        addParseMode();
        addSilent();
        addProtect();
        addReplyTo();
        addReplyMarkup();

      case 'sendDocument':
        final url = context.getParam<String>('documentUrl', '');
        if (url.isEmpty) {
          return _BodyResult.err('Document URL is required for sendDocument');
        }
        addChatId();
        body['document'] = url;
        if (caption.isNotEmpty) body['caption'] = caption;
        addParseMode();
        addSilent();
        addProtect();
        addReplyTo();

      case 'sendVideo':
        final url = context.getParam<String>('videoUrl', '');
        if (url.isEmpty) {
          return _BodyResult.err('Video URL is required for sendVideo');
        }
        addChatId();
        body['video'] = url;
        if (caption.isNotEmpty) body['caption'] = caption;
        addParseMode();
        addSilent();
        addProtect();
        addReplyTo();

      case 'sendSticker':
        final fileId = context.getParam<String>('stickerFileId', '');
        if (fileId.isEmpty) {
          return _BodyResult.err(
              'Sticker file ID is required for sendSticker');
        }
        addChatId();
        body['sticker'] = fileId;
        addSilent();
        addProtect();
        addReplyTo();

      // ── Location ──
      case 'sendLocation':
        final lat = context.getParam<num>('latitude', 0).toDouble();
        final lng = context.getParam<num>('longitude', 0).toDouble();
        if (lat == 0 && lng == 0) {
          return _BodyResult.err(
              'Latitude and longitude are required for sendLocation');
        }
        addChatId();
        body['latitude'] = lat;
        body['longitude'] = lng;
        addSilent();
        addProtect();
        addReplyTo();

      // ── Chat action (typing indicator) ──
      case 'sendChatAction':
        addChatId();
        body['action'] =
            context.getParam<String>('chatAction', 'typing');

      // ── Edit / Delete ──
      case 'editMessageText':
        if (text.isEmpty) {
          return _BodyResult.err(
              'New text is required for editMessageText');
        }
        final msgId = context.getParam<num>('messageId', 0).toInt();
        if (msgId <= 0) {
          return _BodyResult.err(
              'Message ID is required for editMessageText');
        }
        addChatId();
        body['message_id'] = msgId;
        body['text'] = text;
        addParseMode();
        addReplyMarkup();
        if (disableLinkPreview) body['disable_web_page_preview'] = true;

      case 'deleteMessage':
        final msgId = context.getParam<num>('messageId', 0).toInt();
        if (msgId <= 0) {
          return _BodyResult.err(
              'Message ID is required for deleteMessage');
        }
        addChatId();
        body['message_id'] = msgId;

      // ── Forward / Copy ──
      case 'forwardMessage':
        final fromChat = context.getParam<String>('fromChatId', '');
        final msgId = context.getParam<num>('messageId', 0).toInt();
        if (fromChat.isEmpty) {
          return _BodyResult.err(
              'From Chat ID is required for forwardMessage');
        }
        if (msgId <= 0) {
          return _BodyResult.err(
              'Message ID is required for forwardMessage');
        }
        addChatId();
        body['from_chat_id'] = fromChat;
        body['message_id'] = msgId;
        addSilent();
        addProtect();

      case 'copyMessage':
        final fromChat = context.getParam<String>('fromChatId', '');
        final msgId = context.getParam<num>('messageId', 0).toInt();
        if (fromChat.isEmpty) {
          return _BodyResult.err(
              'From Chat ID is required for copyMessage');
        }
        if (msgId <= 0) {
          return _BodyResult.err(
              'Message ID is required for copyMessage');
        }
        addChatId();
        body['from_chat_id'] = fromChat;
        body['message_id'] = msgId;
        if (caption.isNotEmpty) body['caption'] = caption;
        addParseMode();
        addSilent();
        addProtect();

      // ── Pin / Unpin ──
      case 'pinChatMessage':
        final msgId = context.getParam<num>('messageId', 0).toInt();
        if (msgId <= 0) {
          return _BodyResult.err(
              'Message ID is required for pinChatMessage');
        }
        addChatId();
        body['message_id'] = msgId;
        addSilent();

      case 'unpinChatMessage':
        final msgId = context.getParam<num>('messageId', 0).toInt();
        addChatId();
        if (msgId > 0) body['message_id'] = msgId;

      // ── Callback ──
      case 'answerCallbackQuery':
        final queryId =
            context.getParam<String>('callbackQueryId', '');
        if (queryId.isEmpty) {
          return _BodyResult.err(
              'Callback query ID is required for answerCallbackQuery');
        }
        body['callback_query_id'] = queryId;
        if (text.isNotEmpty) body['text'] = text;
        final showAlert = context.getParam<bool>('showAlert', false);
        if (showAlert) body['show_alert'] = true;

      // ── Bot & Chat info ──
      case 'getMe':
        // No body needed
        break;

      case 'getChat':
        addChatId();

      case 'getChatMember':
        final uid = context.getParam<num>('userId', 0).toInt();
        if (uid <= 0) {
          return _BodyResult.err(
              'User ID is required for getChatMember');
        }
        addChatId();
        body['user_id'] = uid;

      // ── Updates (polling) ──
      case 'getUpdates':
        // No required body
        break;

      default:
        return _BodyResult.err('Unknown action: "$action"');
    }

    return _BodyResult.ok(body);
  }

  // ---------------------------------------------------------------------------
  // HTTP call via dart:io
  // ---------------------------------------------------------------------------

  Future<ExecutionResult> _callApi({
    required String botToken,
    required String method,
    required Map<String, dynamic> body,
    required String action,
    required String chatId,
    required ExecutionContext context,
  }) async {
    try {
      final uri = Uri.parse('https://api.telegram.org/bot$botToken/$method');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      dynamic parsed;
      try {
        parsed = jsonDecode(responseBody);
      } catch (_) {
        parsed = responseBody;
      }

      if (response.statusCode != 200) {
        final desc = parsed is Map ? parsed['description'] ?? '' : '';
        return ExecutionResult.error(
          nodeId: context.nodeId,
          message: 'Telegram API error ${response.statusCode}: $desc',
        );
      }

      final isOk = parsed is Map && parsed['ok'] == true;

      return ExecutionResult.success(
        nodeId: context.nodeId,
        outputData: {
          'ok': isOk,
          'result': parsed is Map ? parsed['result'] : parsed,
          'action': action,
          'chatId': chatId,
          'statusCode': response.statusCode,
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

  // ---------------------------------------------------------------------------
  // Template interpolation
  // ---------------------------------------------------------------------------

  /// Replaces `{{fieldName}}` placeholders with values from [data].
  String _interpolate(String template, Map<String, dynamic> data) {
    if (template.isEmpty || !template.contains('{{')) return template;
    return template.replaceAllMapped(
      RegExp(r'\{\{(\w+)\}\}'),
      (match) {
        final key = match.group(1)!;
        return data[key]?.toString() ?? '{{$key}}';
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal body result type
// ---------------------------------------------------------------------------

class _BodyResult {
  const _BodyResult._(this.body, this.error);

  factory _BodyResult.ok(Map<String, dynamic> body) =>
      _BodyResult._(body, null);

  factory _BodyResult.err(String message) =>
      _BodyResult._(const {}, message);

  final Map<String, dynamic> body;
  final String? error;
}
