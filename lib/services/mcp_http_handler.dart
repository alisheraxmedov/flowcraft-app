import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flowcraft/viewmodels/sketch_controller.dart';

import 'app_version.dart';
import 'mcp_tools.dart';

/// Path the MCP endpoint is served from, relative to the control server's
/// loopback origin.
const String mcpEndpointPath = '/mcp';

/// MCP revisions this server speaks, newest first.
///
/// Newest-first matters: [McpHttpHandler] answers `initialize` with the
/// first entry whenever the client asks for something we don't know, which
/// is the spec's "offer your latest" fallback.
const List<String> supportedMcpProtocolVersions = [
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

/// Spelled out because `dart:io`'s [HttpHeaders] has no constant for it —
/// it only predefines the headers an HTTP *client/server* implementation
/// needs itself, and `Origin` is a browser concern.
const String originHeader = 'origin';

/// Whether a request carrying [origin] may reach a loopback-bound server.
///
/// MCP's transport spec requires this check on local servers: DNS
/// rebinding lets an attacker's page resolve their domain to 127.0.0.1 and
/// talk to us, but the browser still stamps the *attacker's* origin on the
/// request and won't let script forge it. A missing Origin is the normal
/// case — CLIs and other non-browser clients don't send one — so it passes.
bool isLoopbackOrigin(String? origin) {
  if (origin == null) return true;
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  return const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
}

/// Ceiling on one request body, shared by the MCP endpoint and the legacy
/// REST one.
///
/// Not a defence against a stranger — the socket is loopback-only and
/// authenticated. It is a defence against the authenticated caller being an
/// agent that mis-generates a runaway payload and takes a *GUI* process
/// down with it, where an out-of-memory kill costs the user unsaved work.
/// 8 MiB is far past what a diagram needs: the wordiest element serializes
/// to a few hundred bytes, so this admits an order of magnitude more than
/// `maxDiagramElements` in `diagram_spec.dart` will accept anyway.
const int maxRequestBodyBytes = 8 * 1024 * 1024;

/// Thrown by [readBoundedBody] when a client sends more than
/// [maxRequestBodyBytes]. Its text carries the limit and nothing else —
/// that number is the whole actionable answer.
class RequestBodyTooLargeException implements Exception {
  const RequestBodyTooLargeException();

  @override
  String toString() =>
      'request body exceeds the $maxRequestBodyBytes byte limit';
}

/// Reads [request]'s body as UTF-8, giving up as soon as it passes
/// [maxRequestBodyBytes] instead of buffering whatever keeps arriving.
///
/// `Content-Length` is consulted first so an honest oversized request is
/// refused before a byte of it is held, but it is only a hint — a chunked
/// body sends none — so the running total is what actually enforces the cap.
Future<String> readBoundedBody(HttpRequest request) async {
  if (request.contentLength > maxRequestBodyBytes) {
    throw const RequestBodyTooLargeException();
  }
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in request) {
    if (buffer.length + chunk.length > maxRequestBodyBytes) {
      throw const RequestBodyTooLargeException();
    }
    buffer.add(chunk);
  }
  return utf8.decode(buffer.takeBytes());
}

/// Answers an over-limit [request] with a 413 carrying [body], then hangs
/// up on it.
///
/// The refusal can't go out through [HttpRequest.response]: `dart:io` holds
/// a response back until the request body has been read, and reading an
/// oversized body just to be polite about refusing it is the exact thing
/// the limit exists to prevent. Detaching the socket puts the answer on the
/// wire now instead.
///
/// A request refused on its declared `Content-Length` was never read, so it
/// gets the full 413. One refused part-way through a chunked body has
/// already had its connection torn down by `dart:io` — there is nothing
/// left to write to, and the abort is itself the answer the client reads.
Future<void> refuseOversizedBody(
  HttpRequest request,
  Map<String, Object?> body,
) async {
  final Socket socket;
  try {
    socket = await request.response.detachSocket(writeHeaders: false);
  } catch (_) {
    return;
  }
  final payload = utf8.encode(jsonEncode(body));
  socket
    ..add(
      utf8.encode(
        'HTTP/1.1 413 Request Entity Too Large\r\n'
        'Content-Type: application/json; charset=utf-8\r\n'
        'Content-Length: ${payload.length}\r\n'
        'Connection: close\r\n\r\n',
      ),
    )
    ..add(payload);
  await socket.flush();
  await socket.close();
}

/// Compares a caller-supplied secret against the real one without stopping
/// at the first byte that differs.
///
/// Against 256 bits of `Random.secure()` over loopback the timing signal
/// this removes is close to unusable — there is no search for it to guide.
/// It is here because a compare that leaks how long a prefix matched is the
/// kind of primitive that gets copied somewhere it does matter. Lengths
/// stay distinguishable; contents do not.
bool constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var mismatch = x.length ^ y.length;
  for (var i = 0; i < x.length; i++) {
    // On a length mismatch the answer is already decided by the seed above;
    // substituting a zero past the end of [y] only keeps the loop in bounds
    // instead of cutting it short.
    mismatch |= x[i] ^ (i < y.length ? y[i] : 0);
  }
  return mismatch == 0;
}

/// Serves MCP over the Streamable HTTP transport, straight out of the
/// running app.
///
/// This is what replaced the separate `mcp_server/` binary: a spec-shaped
/// MCP endpoint needs a JSON-RPC dispatcher and a token check, both of
/// which fit inside the `dart:io` [HttpServer] the app already runs. Tool
/// calls therefore land directly on the live [SketchController] with no
/// second process and no IPC hop.
///
/// Only the simple half of the transport is implemented: every response is
/// a plain `application/json` body. The spec allows that in place of an
/// SSE stream, and we have nothing to push server→client — no sampling, no
/// progress, no long-running work — so a stream would be dead weight.
class McpHttpHandler {
  McpHttpHandler({
    required SketchController controller,
    required String token,
    List<McpTool> tools = flowcraftMcpTools,
  }) : _controller = controller,
       _token = token,
       _tools = tools;

  /// Identifies this server in the `initialize` handshake. The version is
  /// the app's own — see [appVersion] for where a release build gets it.
  static const String serverName = 'flowcraft';
  static const String serverVersion = appVersion;

  /// Server-level guidance handed to the model at handshake time. Carried
  /// over from the stdio bridge so agents behave the same as before, minus
  /// the `flowcraft_launch` step that no longer exists.
  static const String instructions =
      'Draws diagrams live on the FlowCraft desktop whiteboard app. Call '
      'flowcraft_status to check connectivity, then flowcraft_draw with '
      'shapes (rectangles for classes/modules, arrows for relations) to '
      'render the diagram you have analyzed.';

  static const String tokenHeader = 'X-Flowcraft-Token';

  // JSON-RPC 2.0 error codes. -32000..-32099 is the range the spec
  // reserves for implementation-defined server errors.
  static const int _parseError = -32700;
  static const int _invalidRequest = -32600;
  static const int _methodNotFound = -32601;
  static const int _invalidParams = -32602;
  static const int _unauthorized = -32001;
  static const int _methodNotAllowed = -32002;

  final SketchController _controller;
  final String _token;
  final List<McpTool> _tools;

  late final Map<String, McpTool> _toolsByName = {
    for (final tool in _tools) tool.name: tool,
  };

  Future<void> handle(HttpRequest request) async {
    if (!isLoopbackOrigin(request.headers.value(originHeader))) {
      _replyError(
        request,
        HttpStatus.forbidden,
        _invalidRequest,
        'forbidden origin',
      );
      return;
    }

    switch (request.method) {
      case 'POST':
        if (!_isAuthorized(request)) {
          _replyError(
            request,
            HttpStatus.unauthorized,
            _unauthorized,
            'missing or invalid token',
          );
          return;
        }
        await _handleMessage(request);
      case 'DELETE':
        // Session teardown. This transport is stateless — there is no
        // session id and nothing cached per client — so acknowledging is
        // the whole implementation.
        if (!_isAuthorized(request)) {
          _replyError(
            request,
            HttpStatus.unauthorized,
            _unauthorized,
            'missing or invalid token',
          );
          return;
        }
        _replyJson(request, HttpStatus.ok, const {});
      default:
        // GET is the spec's *optional* server→client SSE stream, which we
        // deliberately don't offer (see the class doc), so it — and every
        // other verb — is genuinely unsupported here.
        request.response.headers.set(HttpHeaders.allowHeader, 'POST, DELETE');
        _replyError(
          request,
          HttpStatus.methodNotAllowed,
          _methodNotAllowed,
          'only POST and DELETE are supported on $mcpEndpointPath',
        );
    }
  }

  Future<void> _handleMessage(HttpRequest request) async {
    final Object? message;
    try {
      final body = await readBoundedBody(request);
      message = body.isEmpty ? null : jsonDecode(body);
    } on RequestBodyTooLargeException catch (e) {
      await refuseOversizedBody(request, {
        'jsonrpc': '2.0',
        'id': null,
        ..._error(_invalidRequest, '$e'),
      });
      return;
    } on FormatException catch (e) {
      _replyError(
        request,
        HttpStatus.badRequest,
        _parseError,
        'invalid JSON: ${e.message}',
      );
      return;
    }

    if (message is! Map<String, Object?>) {
      // Revision 2025-06-18 removed JSON-RPC batching, so a top-level
      // array is no longer a message we're expected to understand.
      _replyError(
        request,
        HttpStatus.badRequest,
        _invalidRequest,
        'expected a single JSON-RPC message object',
      );
      return;
    }

    final id = message['id'];
    final method = message['method'];
    if (id == null || method is! String) {
      // A notification (no id) or a response to something we sent. Neither
      // may be answered with a JSON-RPC payload, so the transport's own
      // "received it" acknowledgement is all we return — this is also the
      // path `notifications/initialized` takes.
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
      return;
    }

    _replyJson(request, HttpStatus.ok, {
      'jsonrpc': '2.0',
      'id': id,
      ..._dispatch(method, message['params']),
    });
  }

  /// Runs one JSON-RPC request and returns the half of the response body
  /// that varies: either `result` or `error`.
  Map<String, Object?> _dispatch(String method, Object? params) {
    switch (method) {
      case 'initialize':
        return {'result': _initializeResult(params)};
      case 'ping':
        return const {'result': <String, Object?>{}};
      case 'tools/list':
        return {
          'result': {
            'tools': [for (final tool in _tools) tool.toJson()],
          },
        };
      case 'tools/call':
        return _callTool(params);
      default:
        return _error(_methodNotFound, 'unknown method: $method');
    }
  }

  Map<String, Object?> _initializeResult(Object? params) {
    final requested = params is Map ? params['protocolVersion'] : null;
    return {
      // Echo the client's revision when we speak it, so an older client
      // isn't handed a newer one it can't parse. Otherwise answer with our
      // latest and let the client decide whether to keep going.
      'protocolVersion': supportedMcpProtocolVersions.contains(requested)
          ? requested
          : supportedMcpProtocolVersions.first,
      'capabilities': const {'tools': <String, Object?>{}},
      'serverInfo': const {'name': serverName, 'version': serverVersion},
      'instructions': instructions,
    };
  }

  Map<String, Object?> _callTool(Object? params) {
    if (params is! Map) {
      return _error(_invalidParams, 'tools/call requires a params object');
    }
    final name = params['name'];
    final tool = name is String ? _toolsByName[name] : null;
    if (tool == null) {
      return _error(_invalidParams, 'unknown tool: $name');
    }

    final rawArguments = params['arguments'];
    final arguments = rawArguments is Map
        ? rawArguments.cast<String, Object?>()
        : const <String, Object?>{};

    try {
      return {'result': tool.run(_controller, arguments).toJson()};
    } catch (e) {
      // A tool that blew up is a *tool* failure, not a protocol failure:
      // the model needs to read the reason and correct its next call, so
      // it belongs in the result with `isError: true`.
      return {'result': McpToolResult.failed('$e').toJson()};
    }
  }

  /// Accepts the token from either header: a bearer token is what generic
  /// MCP HTTP clients reach for, while the custom header is what the
  /// legacy stdio bridge and the app's own REST endpoints already use.
  bool _isAuthorized(HttpRequest request) {
    final header = request.headers.value(tokenHeader);
    if (header != null && constantTimeEquals(header, _token)) return true;
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefix = 'Bearer ';
    return authorization.startsWith(prefix) &&
        constantTimeEquals(
          authorization.substring(prefix.length).trim(),
          _token,
        );
  }

  Map<String, Object?> _error(int code, String message) => {
    'error': {'code': code, 'message': message},
  };

  void _replyError(HttpRequest request, int status, int code, String message) {
    _replyJson(request, status, {
      'jsonrpc': '2.0',
      'id': null,
      ..._error(code, message),
    });
  }

  void _replyJson(HttpRequest request, int status, Map<String, Object?> body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}
