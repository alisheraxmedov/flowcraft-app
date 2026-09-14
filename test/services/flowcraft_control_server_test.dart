import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
// Not part of the barrel — the transport's limits are internal to the
// server, but they are exactly what these tests have to name.
import 'package:flowcraft/services/mcp_http_handler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller whose draw path fails with a message that names a local
/// path — what a bug on our side of the HTTP boundary can look like.
class _ExplodingController extends SketchController {
  @override
  void addAll(Iterable<SketchElement> elements) {
    throw StateError('boom at /Users/secret/flowcraft');
  }
}

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

  test('GET /health reports liveness and version without auth', () async {
    final request = await client.getUrl(base.replace(path: '/health'));
    final response = await request.close();
    expect(response.statusCode, 200);
    final json = await readJson(response);
    expect(json['status'], 'ok');
    expect(json['version'], appVersion);
    // What is on the canvas is the user's; an unauthenticated probe learns
    // only that the app is up.
    expect(json.containsKey('elements'), isFalse);
  });

  test('GET /health includes the element count for a valid token', () async {
    controller.add(
      SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
    );
    final request = await client.getUrl(base.replace(path: '/health'));
    request.headers.set('X-Flowcraft-Token', server.token);
    final response = await request.close();

    expect(response.statusCode, 200);
    expect((await readJson(response))['elements'], 1);
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
    final response = await post('/draw', {
      'elements': [
        {
          'type': 'rectangle',
          'x': 40,
          'y': 40,
          'width': 220,
          'height': 90,
          'text': 'UserService',
        },
        {'type': 'arrow', 'fromX': 260, 'fromY': 85, 'toX': 420, 'toY': 85},
      ],
    }, token: server.token);

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

    final response = await post('/draw', {
      'mode': 'replace',
      'elements': [
        {'type': 'ellipse', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
      ],
    }, token: server.token);

    expect(response.statusCode, 200);
    expect(controller.elements, hasLength(1));
    expect(controller.elements.single, isA<SketchEllipse>());
  });

  test('POST /draw rejects an unknown element type', () async {
    final response = await post('/draw', {
      'elements': [
        {'type': 'not_a_real_shape'},
      ],
    }, token: server.token);

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

  test('POST /draw refuses more elements than one call may draw', () async {
    final response = await post('/draw', {
      'elements': [
        for (var i = 0; i <= maxDiagramElements; i++) {'type': 'line'},
      ],
    }, token: server.token);

    expect(response.statusCode, 400);
    expect((await readJson(response))['error'], contains('Too many elements'));
    expect(controller.elements, isEmpty);
  });

  test(
    'POST /draw refuses a body larger than the cap before reading it',
    () async {
      // Raw socket on purpose: the point is that an oversized request is
      // turned away on its declared length, without a byte of the body being
      // buffered — so the test never sends one.
      final socket = await Socket.connect('127.0.0.1', server.boundPort!);
      addTearDown(() => socket.destroy());
      socket.write(
        'POST /draw HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'X-Flowcraft-Token: ${server.token}\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${maxRequestBodyBytes + 1}\r\n'
        '\r\n',
      );
      await socket.flush();

      final status = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 10));

      expect(status, startsWith('HTTP/1.1 413'));
      expect(controller.elements, isEmpty);
    },
  );

  test(
    'POST /draw refuses an oversized body that declares no length',
    () async {
      // The chunked case, where Content-Length can't be trusted to exist: the
      // running total is the only thing standing between an authenticated
      // client and the GUI process's memory.
      final request = await client.postUrl(base.replace(path: '/draw'));
      request.headers.contentType = ContentType.json;
      request.headers.set('X-Flowcraft-Token', server.token);
      // Valid JSON the old code would have accepted — the padding, not a
      // parse failure, is what has to be refused.
      request.write('{"elements":[],"pad":"');
      final chunk = 'x' * (64 * 1024);
      for (var sent = 0; sent <= maxRequestBodyBytes; sent += chunk.length) {
        request.write(chunk);
      }
      request.write('"}');

      // The server hangs up as soon as it has seen enough, so the tail of
      // this write may never land — either outcome is the refusal.
      late final int? status;
      try {
        status = (await request.close()).statusCode;
      } on SocketException {
        status = null;
      } on HttpException {
        status = null;
      }

      expect(status, anyOf(isNull, HttpStatus.requestEntityTooLarge));
      expect(controller.elements, isEmpty);
    },
  );

  test('/draw answers 400 for a wrongly-typed field', () async {
    // `{"text": 42}` used to reach a cast inside the parser rather than one
    // of its own checks, and came back as 500 "internal server error" —
    // untrue, and unfixable from the caller's side.
    for (final bad in [
      {'type': 'rectangle', 'text': 42},
      {'type': 5},
      {'type': 'rectangle', 'strokeColor': 7},
    ]) {
      final response = await post('/draw', {
        'elements': [bad],
      }, token: server.token);

      expect(response.statusCode, 400, reason: '$bad');
      expect((await readJson(response))['error'], contains('must be'));
    }
    expect(controller.elements, isEmpty);
  });

  test('an unexpected failure is not echoed back to the caller', () async {
    // Nothing a caller can send reaches the generic handler any more, so
    // the failure is planted on our side of the boundary — the class of
    // bug whose message can carry local filesystem paths.
    final exploding = _ExplodingController();
    final other = FlowcraftControlServer(
      controller: exploding,
      port: 0,
      configDir: tempConfigDir,
    );
    await other.start();
    addTearDown(other.stop);
    final request = await client.postUrl(
      base.replace(port: other.boundPort, path: '/draw'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set('X-Flowcraft-Token', other.token);
    request.write(
      jsonEncode({
        'elements': [
          {'type': 'rectangle'},
        ],
      }),
    );
    final response = await request.close();

    expect(response.statusCode, 500);
    final body = await response.transform(utf8.decoder).join();
    expect(body, isNot(contains('/Users/secret')));
    expect(jsonDecode(body), {'error': 'internal server error'});
  });

  test('a foreign Origin is refused on the REST endpoints too', () async {
    final request = await client.getUrl(base.replace(path: '/health'));
    request.headers.set('origin', 'http://evil.example');
    final response = await request.close();

    expect(response.statusCode, 403);
  });

  group(
    'token file',
    () {
      /// A server whose config directory it has to create itself.
      /// `createTempSync` already makes a 0700 directory, so reusing the
      /// outer one would pass the directory check without any fix at all.
      Future<FlowcraftControlServer> startWith(Directory configDir) async {
        final other = FlowcraftControlServer(
          controller: controller,
          port: 0,
          configDir: configDir,
        );
        await other.start();
        addTearDown(other.stop);
        return other;
      }

      File tokenFileIn(Directory dir) =>
          File('${dir.path}${Platform.pathSeparator}control.token');

      test('is created readable only by its owner', () async {
        final configDir = Directory(
          '${tempConfigDir.path}${Platform.pathSeparator}fresh',
        );

        final other = await startWith(configDir);

        final file = tokenFileIn(configDir);
        expect(file.readAsStringSync(), other.token);
        expect(file.statSync().modeString(), 'rw-------');
        expect(configDir.statSync().modeString(), 'rwx------');
      });

      test(
        'an already world-readable token is tightened, not rotated',
        () async {
          final configDir = Directory(
            '${tempConfigDir.path}${Platform.pathSeparator}legacy',
          )..createSync();
          final file = tokenFileIn(configDir)
            ..writeAsStringSync('legacy-token');
          Process.runSync('chmod', ['644', file.path]);
          Process.runSync('chmod', ['755', configDir.path]);

          final other = await startWith(configDir);

          // Rotating instead would silently break every CLI already registered
          // against this app, so the fix has to be the permissions alone.
          expect(other.token, 'legacy-token');
          expect(file.statSync().modeString(), 'rw-------');
          expect(configDir.statSync().modeString(), 'rwx------');
        },
      );
    },
    skip: Platform.isWindows
        ? 'POSIX mode bits; Windows carries this on the profile ACL'
        : null,
  );

  group('MCP endpoint', () {
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
      expect(result['serverInfo'], containsPair('name', isA<String>()));
      expect(result['serverInfo'], containsPair('version', appVersion));
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

    test('tools/list advertises the full read/edit canvas tool set', () async {
      final body = await rpc('tools/list');

      final tools = (body['result'] as Map<String, dynamic>)['tools'] as List;
      expect(tools.map((t) => (t as Map<String, dynamic>)['name']), [
        'flowcraft_status',
        'flowcraft_read',
        'flowcraft_draw',
        'flowcraft_update',
        'flowcraft_delete',
        'flowcraft_clear',
      ]);
      // A tool without a usable schema is unusable to a model, so make
      // sure the full JSON Schema survives serialization.
      final draw =
          tools.firstWhere(
                (t) => (t as Map<String, dynamic>)['name'] == 'flowcraft_draw',
              )
              as Map<String, dynamic>;
      final schema = draw['inputSchema'] as Map<String, dynamic>;
      expect(schema['type'], 'object');
      expect(schema['required'], ['elements']);
      expect(
        (schema['properties'] as Map<String, dynamic>).keys,
        containsAll(['mode', 'elements']),
      );
    });

    test(
      'flowcraft_read, _update and _delete round-trip over the wire',
      () async {
        // Draw two shapes, read them back to learn their ids, move one and
        // delete the other — the whole point of the read/edit surface.
        await rpc(
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
                  'text': 'A',
                },
                {
                  'type': 'ellipse',
                  'x': 300,
                  'y': 0,
                  'width': 50,
                  'height': 50,
                },
              ],
            },
          },
        );

        final read = await rpc(
          'tools/call',
          params: {'name': 'flowcraft_read', 'arguments': <String, dynamic>{}},
        );
        final readResult = read['result'] as Map<String, dynamic>;
        expect(readResult['isError'], isFalse);
        final decoded =
            jsonDecode((readResult['content'] as List).single['text'] as String)
                as Map<String, dynamic>;
        expect(decoded['count'], 2);
        final described = (decoded['elements'] as List).cast<Map>();
        final rectId = described.firstWhere(
          (e) => e['type'] == 'rectangle',
        )['id'];
        final ellipseId = described.firstWhere(
          (e) => e['type'] == 'ellipse',
        )['id'];

        await rpc(
          'tools/call',
          params: {
            'name': 'flowcraft_update',
            'arguments': {
              'elements': [
                {'id': rectId, 'x': 40, 'text': 'Renamed'},
              ],
            },
          },
        );

        // Only the addressed rectangle moved and was relabelled; the ellipse
        // is untouched, and the id is preserved (it was updated, not replaced).
        final rect =
            controller.elements.firstWhere((e) => e.id == rectId)
                as SketchRectangle;
        expect(rect.rect.left, 40);
        expect(rect.rect.width, 200);
        expect(rect.text, 'Renamed');

        await rpc(
          'tools/call',
          params: {
            'name': 'flowcraft_delete',
            'arguments': {
              'ids': [ellipseId],
            },
          },
        );

        expect(controller.elements.map((e) => e.id), [rectId]);
      },
    );

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
      expect(
        (controller.elements.single as SketchRectangle).text,
        'OrderService',
      );
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
        containsPair(
          'text',
          allOf(contains('1 element(s)'), contains('version $appVersion')),
        ),
      );
    });

    test(
      'a wrongly-typed field is a tool error the model can act on',
      () async {
        final body = await rpc(
          'tools/call',
          params: {
            'name': 'flowcraft_draw',
            'arguments': {
              'elements': [
                {'type': 'text', 'text': 5},
              ],
            },
          },
        );

        expect(body['error'], isNull);
        final result = body['result'] as Map<String, dynamic>;
        expect(result['isError'], isTrue);
        expect(
          (result['content'] as List).single,
          containsPair('text', contains('"text" must be a string')),
        );
        expect(controller.elements, isEmpty);
      },
    );

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

    test(
      'a non-finite coordinate is a tool error the model can act on',
      () async {
        // Hand-written rather than encoded: `jsonEncode` refuses to emit a
        // non-finite double, which is precisely why `1e999` is the way one
        // reaches the parser.
        final response = await mcp(
          '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":'
          '{"name":"flowcraft_draw","arguments":{"elements":'
          '[{"type":"rectangle","x":0,"y":0,"width":1e999,"height":80}]}}}',
          token: server.token,
        );

        expect(response.statusCode, 200);
        final body = await readJson(response);
        expect(
          body['error'],
          isNull,
          reason: 'a tool failure, not a protocol one',
        );
        final result = body['result'] as Map<String, dynamic>;
        expect(result['isError'], isTrue);
        expect(
          (result['content'] as List).single,
          containsPair('text', contains('finite')),
        );
        expect(controller.elements, isEmpty);
      },
    );

    test('too many elements is a tool error, not a drawn canvas', () async {
      final body = await rpc(
        'tools/call',
        params: {
          'name': 'flowcraft_draw',
          'arguments': {
            'elements': [
              for (var i = 0; i <= maxDiagramElements; i++) {'type': 'line'},
            ],
          },
        },
      );

      final result = body['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(
        (result['content'] as List).single,
        containsPair('text', contains('Too many elements')),
      );
      expect(controller.elements, isEmpty);
    });

    test('an oversized body is refused on /mcp too', () async {
      final socket = await Socket.connect('127.0.0.1', server.boundPort!);
      addTearDown(() => socket.destroy());
      socket.write(
        'POST /mcp HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'X-Flowcraft-Token: ${server.token}\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${maxRequestBodyBytes + 1}\r\n'
        '\r\n',
      );
      await socket.flush();

      final status = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 10));

      expect(status, startsWith('HTTP/1.1 413'));
    });

    test('a wrong token of any length is rejected', () async {
      for (final wrong in [
        '',
        'x',
        server.token.substring(0, server.token.length - 1),
        '${server.token}x',
        'x' * 4096,
      ]) {
        final response = await mcp(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
          token: wrong,
        );

        expect(response.statusCode, 401, reason: 'accepted "$wrong"');
        await response.drain<void>();
      }
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

    test('a batched array is rejected — 2025-06-18 removed batching', () async {
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

    test(
      'a foreign Origin is refused before auth is even considered',
      () async {
        final response = await mcp(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
          token: server.token,
          origin: 'http://evil.example',
        );

        expect(response.statusCode, 403);
      },
    );

    test('a localhost Origin is allowed', () async {
      final response = await mcp(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
        token: server.token,
        origin: 'http://localhost:3000',
      );

      expect(response.statusCode, 200);
    });

    test(
      'GET is method-not-allowed — there is no server→client stream',
      () async {
        final request = await client.getUrl(base.replace(path: '/mcp'));
        final response = await request.close();

        expect(response.statusCode, 405);
        expect(response.headers.value(HttpHeaders.allowHeader), 'POST, DELETE');
        await response.drain<void>();
      },
    );

    test('DELETE acknowledges the (stateless) session teardown', () async {
      final request = await client.deleteUrl(base.replace(path: '/mcp'));
      request.headers.set('X-Flowcraft-Token', server.token);
      final response = await request.close();

      expect(response.statusCode, 200);
      await response.drain<void>();
    });
  });
}
