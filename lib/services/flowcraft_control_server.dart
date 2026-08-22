import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

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
/// `~/.flowcraft/control.token` on first start. That file and its parent
/// are restricted to their owner on POSIX, so drawing means being the user
/// who runs the app — or anything that can already read that user's home
/// directory, root included. On Windows the profile's own ACL is what
/// carries that guarantee; see [_restrictToOwner].
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
      if (existing.isNotEmpty) {
        // Re-tightened on every start, not only at creation: an install
        // predating this left a world-readable token behind, and rotating
        // it would break the CLI registrations already pointing at it.
        _restrictToOwner(file.parent, _ownerOnlyDirMode);
        _restrictToOwner(file, _ownerOnlyFileMode);
        return existing;
      }
    }
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final token = base64Url.encode(bytes);
    file.parent.createSync(recursive: true);
    // Directory first: with the search bit already off for everyone else,
    // the token never spends even a moment reachable at its default mode.
    _restrictToOwner(file.parent, _ownerOnlyDirMode);
    file.writeAsStringSync(token);
    _restrictToOwner(file, _ownerOnlyFileMode);
    return token;
  }

  static const String _ownerOnlyFileMode = '600';
  static const String _ownerOnlyDirMode = '700';

  /// Takes the group and world bits off [entity].
  ///
  /// `dart:io` can read a mode ([FileStat.mode]) but not set one, and this
  /// app ships zero plugins on purpose, so the platform tool is the only
  /// route — invoked as an argv list, never through a shell. Windows has no
  /// mode bits to clear: `%USERPROFILE%` already inherits an ACL granting
  /// only the profile owner, and an `icacls` call here would restate it.
  ///
  /// Best effort by design. A token the whole machine can read is bad; a
  /// whiteboard that refuses to open because `chmod` was missing is worse,
  /// so a failure is printed for the developer and stepped over.
  static void _restrictToOwner(FileSystemEntity entity, String mode) {
    if (Platform.isWindows) return;
    try {
      final result = Process.runSync('chmod', [mode, entity.path]);
      if (result.exitCode != 0) {
        debugPrint(
          'FlowCraft could not restrict ${entity.path}: ${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('FlowCraft could not restrict ${entity.path}: $e');
    }
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
            final raw = body['elements'] ?? const <dynamic>[];
            // Type-checked rather than cast: a cast failure would land in
            // the generic handler below and come back as "internal server
            // error", which is both untrue and unfixable from out there.
            if (raw is! List) {
              throw DiagramSpecException('"elements" must be an array.');
            }
            final elements = parseDiagramElements(raw);
            // Compared, not cast, for the same reason as `elements` above;
            // anything that isn't the literal "replace" appends, matching
            // the MCP tool so the two dialects can't diverge.
            if (body['mode'] == 'replace') {
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
    } on RequestBodyTooLargeException catch (e) {
      await refuseOversizedBody(request, {'error': '$e'});
    } on DiagramSpecException catch (e) {
      _reply(request, 400, {'error': e.message});
    } on FormatException catch (e) {
      _reply(request, 400, {'error': 'invalid JSON: ${e.message}'});
    } catch (e) {
      // Everything above is something the caller can fix and is told how to
      // fix. Reaching here instead means a bug on our side, whose text can
      // name local paths, so the caller gets the fact and the developer
      // gets the detail. Tool failures deliberately don't come through
      // here — `tools/call` answers those with the reason attached, because
      // a model is expected to read it and correct its next call.
      debugPrint('FlowCraft control server: unhandled request failure: $e');
      _reply(request, 500, {'error': 'internal server error'});
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
    if (header == null || !constantTimeEquals(header, _token)) {
      _reply(request, 401, {'error': 'missing or invalid token'});
      return;
    }
    await action();
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final body = await readBoundedBody(request);
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected a JSON object');
    }
    return decoded;
  }

  void _reply(HttpRequest request, int status, Map<String, dynamic> body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}
