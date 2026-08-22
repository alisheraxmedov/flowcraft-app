import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempConfigDir;
  late SketchController controller;
  late FlowcraftControlServer server;
  late HttpClient client;
  late Uri base;

  setUp(() async {
    tempConfigDir = Directory.systemTemp.createTempSync('flowcraft_test_');
    controller = SketchController(currentTool: SketchTool.select);
    server = FlowcraftControlServer(
      controller: controller,
      port: 0,
      configDir: tempConfigDir,
    );
    await server.start();
    base = Uri.parse('http://127.0.0.1:${server.boundPort}');
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    controller.dispose();
    tempConfigDir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final request = await client.postUrl(base.replace(path: path));
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('X-Flowcraft-Token', token);
    request.write(jsonEncode(body));
    return request.close();
  }

  Future<Map<String, dynamic>> readJson(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<HttpClientResponse> mcp(
    String body, {
    String? token,
    String? bearer,
    String? origin,
  }) async {
    final request = await client.postUrl(base.replace(path: '/mcp'));
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('X-Flowcraft-Token', token);
    if (bearer != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
    if (origin != null) request.headers.set('origin', origin);
    request.write(body);
    return request.close();
  }

  /// Sends one authenticated JSON-RPC request and returns its decoded
  /// response, asserting the transport itself was happy.
  Future<Map<String, dynamic>> rpc(
    String method, {
    Map<String, dynamic>? params,
  }) async {
    final response = await mcp(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': ?params,
      }),
      token: server.token,
    );
    expect(response.statusCode, 200);
    return readJson(response);
  }

  test('GET /health reports element count without auth', () async {
    final request = await client.getUrl(base.replace(path: '/health'));
    final response = await request.close();
    expect(response.statusCode, 200);
    final json = await readJson(response);
    expect(json['status'], 'ok');
    expect(json['elements'], 0);
  });

  test('POST /draw without a token is rejected', () async {
    final response = await post('/draw', {
      'elements': [
        {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 100, 'height': 60},
      ],
    });
    expect(response.statusCode, 401);
    expect(controller.elements, isEmpty);
  });

  test('POST /draw adds shapes to the live controller', () async {
    final response = await post(
      '/draw',
      {
        'elements': [
          {
            'type': 'rectangle',
            'x': 40,
            'y': 40,
            'width': 220,
            'height': 90,
            'text': 'UserService',
          },
          {
            'type': 'arrow',
            'fromX': 260,
            'fromY': 85,
            'toX': 420,
            'toY': 85,
          },
        ],
      },
      token: server.token,
    );

    expect(response.statusCode, 200);
    final json = await readJson(response);
    expect(json['elements'], 2);
    expect(controller.elements, hasLength(2));
    expect(controller.elements[0], isA<SketchRectangle>());
    expect((controller.elements[0] as SketchRectangle).text, 'UserService');
    expect(controller.elements[1], isA<SketchArrow>());
  });

  test('POST /draw with mode=replace clears prior shapes first', () async {
    controller.add(
      SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
    );

    final response = await post(
      '/draw',
      {
        'mode': 'replace',
        'elements': [
          {'type': 'ellipse', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
        ],
      },
      token: server.token,
    );

    expect(response.statusCode, 200);
    expect(controller.elements, hasLength(1));
    expect(controller.elements.single, isA<SketchEllipse>());
  });

  test('POST /draw rejects an unknown element type', () async {
    final response = await post(
      '/draw',
      {
        'elements': [
          {'type': 'not_a_real_shape'},
        ],
      },
      token: server.token,
    );

    expect(response.statusCode, 400);
    expect(controller.elements, isEmpty);
  });

  test('POST /clear empties the canvas', () async {
    controller.add(
      SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
    );

    final response = await post('/clear', const {}, token: server.token);

    expect(response.statusCode, 200);
    expect(controller.elements, isEmpty);
  });

  test('a foreign Origin is refused on the REST endpoints too', () async {
    final request = await client.getUrl(base.replace(path: '/health'));
    request.headers.set('origin', 'http://evil.example');
    final response = await request.close();

    expect(response.statusCode, 403);
  });

  group('MCP endpoint', () {
    test('exposes its URL once a port is bound', () {
      expect(server.mcpEndpoint, 'http://127.0.0.1:${server.boundPort}/mcp');
    });

    test('initialize echoes a protocol version we support', () async {
      final body = await rpc(
        'initialize',
        params: {
          'protocolVersion': '2025-03-26',
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
        },
      );

      final result = body['result'] as Map<String, dynamic>;
      expect(body['jsonrpc'], '2.0');
      expect(body['id'], 1);
      expect(result['protocolVersion'], '2025-03-26');
      expect(result['capabilities'], containsPair('tools', isA<Map>()));
      expect(
        result['serverInfo'],
        containsPair('name', isA<String>()),
      );
      expect(result['instructions'], contains('flowcraft_draw'));
    });

    test('initialize falls back to our latest unknown version', () async {
      final body = await rpc(
        'initialize',
        params: {'protocolVersion': '1999-01-01'},
      );

      final result = body['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2025-06-18');
    });

    test('notifications are acknowledged with 202 and no body', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
        token: server.token,
      );

      expect(response.statusCode, 202);
      expect(await response.transform(utf8.decoder).join(), isEmpty);
    });

    test('ping answers with an empty result', () async {
      final body = await rpc('ping');

      expect(body['result'], isEmpty);
    });

    test('tools/list advertises exactly the three canvas tools', () async {
      final body = await rpc('tools/list');

      final tools = (body['result'] as Map<String, dynamic>)['tools'] as List;
      expect(
        tools.map((t) => (t as Map<String, dynamic>)['name']),
        ['flowcraft_status', 'flowcraft_draw', 'flowcraft_clear'],
      );
      // A tool without a usable schema is unusable to a model, so make
      // sure the full JSON Schema survives serialization.
      final draw = tools[1] as Map<String, dynamic>;
      final schema = draw['inputSchema'] as Map<String, dynamic>;
      expect(schema['type'], 'object');
      expect(schema['required'], ['elements']);
      expect(
        (schema['properties'] as Map<String, dynamic>).keys,
        containsAll(['mode', 'elements']),
      );
    });

    test('tools/call flowcraft_draw mutates the live controller', () async {
      final body = await rpc(
        'tools/call',
        params: {
          'name': 'flowcraft_draw',
          'arguments': {
            'elements': [
              {
                'type': 'rectangle',
                'x': 10,
                'y': 20,
                'width': 200,
                'height': 80,
                'text': 'OrderService',
              },
            ],
          },
        },
      );

      final result = body['result'] as Map<String, dynamic>;
      expect(result['isError'], isFalse);
      expect(
        (result['content'] as List).single,
        containsPair('text', contains('Drew 1 element(s)')),
      );
      expect(controller.elements, hasLength(1));
      expect((controller.elements.single as SketchRectangle).text,
          'OrderService');
    });

    test('tools/call flowcraft_draw honours mode=replace', () async {
      controller.add(
        SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
      );

      await rpc(
        'tools/call',
        params: {
          'name': 'flowcraft_draw',
          'arguments': {
            'mode': 'replace',
            'elements': [
              {'type': 'ellipse', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
            ],
          },
        },
      );

      expect(controller.elements.single, isA<SketchEllipse>());
    });

    test('tools/call flowcraft_clear empties the canvas', () async {
      controller.add(
        SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
      );

      await rpc(
        'tools/call',
        params: {'name': 'flowcraft_clear', 'arguments': <String, dynamic>{}},
      );

      expect(controller.elements, isEmpty);
    });

    test('tools/call flowcraft_status reports the element count', () async {
      controller.add(
        SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
      );

      final body = await rpc(
        'tools/call',
        params: {'name': 'flowcraft_status'},
      );

      final result = body['result'] as Map<String, dynamic>;
      expect(result['isError'], isFalse);
      expect(
        (result['content'] as List).single,
        containsPair('text', contains('1 element(s)')),
      );
    });

    test('an unknown tool is a JSON-RPC error', () async {
      final body = await rpc(
        'tools/call',
        params: {'name': 'flowcraft_teleport'},
      );

      expect(body['result'], isNull);
      expect(body['error'], containsPair('code', -32602));
    });

    test('a failing tool reports isError, not a JSON-RPC error', () async {
      final body = await rpc(
        'tools/call',
        params: {
          'name': 'flowcraft_draw',
          'arguments': {
            'elements': [
              {'type': 'not_a_real_shape'},
            ],
          },
        },
      );

      expect(body['error'], isNull);
      final result = body['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(
        (result['content'] as List).single,
        containsPair('text', contains('not_a_real_shape')),
      );
      expect(controller.elements, isEmpty);
    });

    test('an unknown method is method-not-found', () async {
      final body = await rpc('resources/list');

      expect(body['error'], containsPair('code', -32601));
    });

    test('malformed JSON is a parse error', () async {
      final response = await mcp('{not json', token: server.token);

      expect(response.statusCode, 400);
      final body = await readJson(response);
      expect(body['error'], containsPair('code', -32700));
    });

    test('a batched array is rejected — 2025-06-18 removed batching',
        () async {
      final response = await mcp(
        jsonEncode([
          {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        ]),
        token: server.token,
      );

      expect(response.statusCode, 400);
      final body = await readJson(response);
      expect(body['error'], containsPair('code', -32600));
    });

    test('a missing token is rejected', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}),
      );

      expect(response.statusCode, 401);
      final body = await readJson(response);
      expect(body['error'], containsPair('code', -32001));
    });

    test('a wrong token is rejected', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}),
        token: 'not-the-token',
      );

      expect(response.statusCode, 401);
    });

    test('the token is also accepted as a bearer token', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
        bearer: server.token,
      );

      expect(response.statusCode, 200);
    });

    test('a foreign Origin is refused before auth is even considered',
        () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
        token: server.token,
        origin: 'http://evil.example',
      );

      expect(response.statusCode, 403);
    });

    test('a localhost Origin is allowed', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
        token: server.token,
        origin: 'http://localhost:3000',
      );

      expect(response.statusCode, 200);
    });

    test('GET is method-not-allowed — there is no server→client stream',
        () async {
      final request = await client.getUrl(base.replace(path: '/mcp'));
      final response = await request.close();

      expect(response.statusCode, 405);
      expect(response.headers.value(HttpHeaders.allowHeader), 'POST, DELETE');
      await response.drain<void>();
    });

    test('DELETE acknowledges the (stateless) session teardown', () async {
      final request = await client.deleteUrl(base.replace(path: '/mcp'));
      request.headers.set('X-Flowcraft-Token', server.token);
      final response = await request.close();

      expect(response.statusCode, 200);
      await response.drain<void>();
    });
  });
}
