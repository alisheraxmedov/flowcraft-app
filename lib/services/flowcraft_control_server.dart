import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'diagram_spec.dart';
import 'mcp_http_handler.dart';

/// Local control server embedded in the FlowCraft desktop app.
///
/// This is the "hand" that AI agents ultimately drive, and it speaks two
/// dialects on one loopback socket:
///
/// * `/mcp` — a full MCP server over the Streamable HTTP transport, so an
///   AI CLI can be pointed straight at the running app with no second
///   process to install. See [McpHttpHandler].
/// * `/health`, `/draw`, `/clear` — the original private REST API, kept
///   for the legacy stdio bridge in `mcp_server/`.
///
/// Both end up in the same place: mutations on the live
/// [SketchController] the whiteboard UI is already watching.
///
/// Security: binds to loopback only (127.0.0.1), rejects browser origins
/// that aren't themselves local (DNS-rebinding defense), and requires
/// every mutating request to carry the token this class writes to
/// `~/.flowcraft/control.token` on first start, so only processes running
/// as the same local user can draw.
class FlowcraftControlServer {
  FlowcraftControlServer({
    required SketchController controller,
    this.port = 5199,
    Directory? configDir,
  })  : _controller = controller,
        _configDir = configDir ?? _defaultConfigDir();

  static Directory _defaultConfigDir() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return Directory('$home${Platform.pathSeparator}.flowcraft');
  }

  final SketchController _controller;
  final int port;
  final Directory _configDir;

  HttpServer? _server;

  /// The port actually bound after [start] (differs from [port] when 0
  /// was requested, e.g. in tests).
  int? get boundPort => _server?.port;

  /// The shared auth token mutating requests must send via the
  /// `X-Flowcraft-Token` header (or `Authorization: Bearer` on `/mcp`).
  String get token => _token;

  /// The URL to register with an AI CLI, once [start] has bound a port.
  /// Null before that — the port isn't known until the socket exists.
  String? get mcpEndpoint {
    final port = boundPort;
    return port == null ? null : 'http://127.0.0.1:$port$mcpEndpointPath';
  }

  /// Built lazily so the token file is only touched when the server
  /// actually starts, not when this class is merely constructed.
  late final McpHttpHandler _mcp = McpHttpHandler(
    controller: _controller,
    token: _token,
  );

  File get _tokenFile =>
      File('${_configDir.path}${Platform.pathSeparator}control.token');

  late final String _token = _loadOrCreateToken();

  String _loadOrCreateToken() {
    final file = _tokenFile;
    if (file.existsSync()) {
      final existing = file.readAsStringSync().trim();
      if (existing.isNotEmpty) return existing;
    }
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final token = base64Url.encode(bytes);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(token);
    return token;
  }

  Future<void> start() async {
    if (_server != null) return;
    _token; // Ensure the token exists before we start accepting requests.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      // The MCP endpoint speaks JSON-RPC end to end, including its own
      // auth and origin failures, so it owns the whole request.
      if (request.uri.path == mcpEndpointPath) {
        await _mcp.handle(request);
        return;
      }
      // Same DNS-rebinding defense for the REST half — a malicious page
      // can't read the token, but it costs nothing to refuse it outright.
      if (!isLoopbackOrigin(request.headers.value(originHeader))) {
        _reply(request, 403, {'error': 'forbidden origin'});
        return;
      }
      switch ('${request.method} ${request.uri.path}') {
        case 'GET /health':
          _reply(request, 200, {
            'status': 'ok',
            'elements': _controller.elements.length,
          });
        case 'POST /draw':
          await _requireAuth(request, () async {
            final body = await _readJson(request);
            final elements = parseDiagramElements(
              body['elements'] as List<dynamic>? ?? const [],
            );
            if ((body['mode'] as String?) == 'replace') {
              _controller.replaceAll(elements);
            } else {
              _controller.addAll(elements);
            }
            _reply(request, 200, {'elements': _controller.elements.length});
          });
        case 'POST /clear':
          await _requireAuth(request, () async {
            _controller.clear();
            _reply(request, 200, {'elements': 0});
          });
        default:
          _reply(request, 404, {'error': 'not found'});
      }
    } on DiagramSpecException catch (e) {
      _reply(request, 400, {'error': e.message});
    } on FormatException catch (e) {
      _reply(request, 400, {'error': 'invalid JSON: ${e.message}'});
    } catch (e) {
      _reply(request, 500, {'error': '$e'});
    }
  }

  /// The REST half deliberately accepts the custom header only — the
  /// `Authorization: Bearer` alternative exists for `/mcp`, where generic
  /// MCP clients expect it. This side has exactly one known caller.
  Future<void> _requireAuth(
    HttpRequest request,
    Future<void> Function() action,
  ) async {
    final header = request.headers.value(McpHttpHandler.tokenHeader);
    if (header == null || header != _token) {
      _reply(request, 401, {'error': 'missing or invalid token'});
      return;
    }
    await action();
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) return const {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  void _reply(HttpRequest request, int status, Map<String, dynamic> body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}
