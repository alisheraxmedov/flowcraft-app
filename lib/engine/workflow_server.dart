import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flowcraft/controller/flow_controller.dart';
import 'package:flowcraft/core/models/flow_node.dart';
import 'package:flowcraft/engine/workflow_result.dart';

/// Event emitted by [WorkflowServer] for status tracking.
class WorkflowServerEvent {
  const WorkflowServerEvent({
    required this.type,
    this.message = '',
    this.data,
  });

  final WorkflowServerEventType type;
  final String message;
  final Map<String, dynamic>? data;

  @override
  String toString() => 'WorkflowServerEvent($type: $message)';
}

/// Types of events the server emits.
enum WorkflowServerEventType {
  started,
  stopped,
  requestReceived,
  executionStarted,
  executionCompleted,
  executionFailed,
  error,
}

/// Live HTTP server that receives webhook requests and executes workflows.
///
/// Binds to a local port, matches incoming requests against webhook trigger
/// nodes by path and method, executes the workflow with the request body
/// as input, and returns the final output as an HTTP JSON response.
///
/// Usage:
/// ```dart
/// final server = WorkflowServer(controller: myController);
/// await server.start(port: 8080);
/// // Now: curl -X POST http://localhost:8080/webhook -d '{"msg":"hi"}'
/// await server.stop();
/// ```
class WorkflowServer {
  WorkflowServer({
    required this.controller,
    this.credentials = const {},
  });

  final FlowController controller;

  /// Credentials (API keys, tokens) passed to every workflow execution.
  Map<String, dynamic> credentials;

  HttpServer? _server;
  final _eventController = StreamController<WorkflowServerEvent>.broadcast();

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// The port the server is listening on (null if not running).
  int? get port => _server?.port;

  /// Stream of server events for UI feedback.
  Stream<WorkflowServerEvent> get events => _eventController.stream;

  /// Starts the HTTP server on the given [port].
  ///
  /// Binds to `0.0.0.0` so the server is accessible from any interface.
  /// Set [host] to `localhost` to restrict to local-only access.
  Future<void> start({
    int port = 8080,
    String host = '0.0.0.0',
  }) async {
    if (_server != null) {
      throw StateError(
          'WorkflowServer is already running on port ${_server!.port}');
    }

    try {
      _server = await HttpServer.bind(host, port);
      _emit(WorkflowServerEventType.started,
          'Server listening on $host:$port');

      _server!.listen(
        _handleRequest,
        onError: (Object error) {
          _emit(WorkflowServerEventType.error, 'Server error: $error');
        },
      );
    } catch (e) {
      _emit(WorkflowServerEventType.error, 'Failed to start server: $e');
      rethrow;
    }
  }

  /// Stops the server gracefully.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _emit(WorkflowServerEventType.stopped, 'Server stopped');
  }

  /// Disposes the event stream controller.
  void dispose() {
    stop();
    _eventController.close();
  }

  // ── Request Handling ─────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for browser-based testing
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, OPTIONS')
      ..add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    // Handle preflight CORS requests
    if (request.method.toUpperCase() == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final method = request.method.toUpperCase();
    final path = request.uri.path;

    _emit(
      WorkflowServerEventType.requestReceived,
      '$method $path',
      {'method': method, 'path': path},
    );

    // Parse request body
    Map<String, dynamic> body;
    try {
      final rawBody = await utf8.decoder.bind(request).join();
      body = rawBody.isNotEmpty
          ? (jsonDecode(rawBody) as Map<String, dynamic>)
          : <String, dynamic>{};
    } catch (e) {
      _respondError(request.response, 400, 'Invalid JSON body: $e');
      return;
    }

    // Find matching webhook trigger node
    final webhookNode = _findWebhookNode(method, path);
    if (webhookNode == null) {
      _respondError(
        request.response,
        404,
        'No webhook trigger found for $method $path',
      );
      return;
    }

    // Execute workflow
    _emit(WorkflowServerEventType.executionStarted, 'Executing workflow...');

    try {
      // Temporarily inject the real request body into the webhook node's data
      final originalPayload = webhookNode.data['testPayload'];
      webhookNode.data['testPayload'] = body;

      final result = await controller.executeWorkflow(
        credentials: credentials,
      );

      // Restore original test payload
      webhookNode.data['testPayload'] = originalPayload;

      // Debug: Log all node results
      for (final entry in result.nodeResults.entries) {
        final node = controller.nodes.where((n) => n.id == entry.key);
        final label = node.isNotEmpty ? node.first.label : 'unknown';
        final defType = node.isNotEmpty
            ? node.first.data['definitionType']
            : 'unknown';
        debugPrint(
            'FlowCraft DEBUG: Node "$label" ($defType) => ${entry.value.status.name} | output: ${entry.value.outputData}');
      }

      if (result.isSuccess) {
        _emit(
          WorkflowServerEventType.executionCompleted,
          'Workflow completed in ${result.duration.inMilliseconds}ms',
        );

        final output = _extractFinalOutput(result, webhookNode);

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': true,
            'duration_ms': result.duration.inMilliseconds,
            'output': output,
          }));
        await request.response.close();
      } else {
        _emit(
          WorkflowServerEventType.executionFailed,
          'Workflow failed: ${result.errors.join(", ")}',
        );

        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': false,
            'errors': result.errors,
            'duration_ms': result.duration.inMilliseconds,
          }));
        await request.response.close();
      }
    } catch (e) {
      _emit(WorkflowServerEventType.executionFailed, 'Execution error: $e');
      _respondError(request.response, 500, 'Workflow execution failed: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Finds a webhook trigger node matching the given HTTP method and path.
  FlowNode? _findWebhookNode(String method, String path) {
    for (final node in controller.nodes) {
      final defType = node.data['definitionType']?.toString();
      if (defType != 'webhook') continue;

      final nodeMethod =
          (node.data['method']?.toString() ?? 'POST').toUpperCase();
      final nodePath = node.data['path']?.toString() ?? '/webhook';

      if (nodeMethod == method && _pathMatches(nodePath, path)) {
        return node;
      }
    }
    return null;
  }

  /// Simple path matching — strips trailing slashes and compares.
  bool _pathMatches(String expected, String actual) {
    String normalize(String p) =>
        p.endsWith('/') && p.length > 1
            ? p.substring(0, p.length - 1)
            : p;
    return normalize(expected) == normalize(actual);
  }

  /// Extracts the final output from the workflow result.
  ///
  /// Priority:
  /// 1. Output node result (definitionType == 'output')
  /// 2. Graph traversal: Find the furthest downstream node from the webhook
  /// 3. Fallback: Last successful node
  Map<String, dynamic> _extractFinalOutput(
      WorkflowResult result, FlowNode webhookNode) {
    // 1. Check for explicit output nodes
    for (final node in controller.nodes) {
      if (node.data['definitionType'] == 'output') {
        final nodeResult = result.nodeResults[node.id];
        if (nodeResult != null && nodeResult.isSuccess) {
          return nodeResult.outputData;
        }
      }
    }

    // 2. Traverse the graph to find the terminal node
    String currentNodeId = webhookNode.id;
    bool foundNext = true;

    // Follow edges downstream until we hit a node with no outgoing edges
    while (foundNext) {
      foundNext = false;
      final outgoingEdges = controller.graph.edges
          .where((e) => e.sourceNodeId == currentNodeId)
          .toList();

      if (outgoingEdges.isNotEmpty) {
        // Just take the first outgoing edge path for now
        currentNodeId = outgoingEdges.first.targetNodeId;
        foundNext = true;
      }
    }

    final terminalResult = result.nodeResults[currentNodeId];
    if (terminalResult != null && terminalResult.isSuccess) {
      return terminalResult.outputData;
    }

    // 3. Fallback
    final successResults =
        result.nodeResults.values.where((r) => r.isSuccess).toList();
    if (successResults.isNotEmpty) {
      return successResults.last.outputData;
    }

    return {'message': 'No output produced'};
  }

  void _respondError(
      HttpResponse response, int statusCode, String message) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'success': false, 'error': message}));
    response.close();
  }

  void _emit(WorkflowServerEventType type, String message,
      [Map<String, dynamic>? data]) {
    debugPrint('FlowCraft WorkflowServer: $message');
    if (!_eventController.isClosed) {
      _eventController.add(WorkflowServerEvent(
        type: type,
        message: message,
        data: data,
      ));
    }
  }
}
