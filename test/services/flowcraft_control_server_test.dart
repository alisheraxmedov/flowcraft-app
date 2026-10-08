import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
// Not part of the barrel — the transport's limits are internal to the
// server, but they are exactly what these tests have to name.
import 'package:flowcraft/services/mcp_http_handler.dart';
import 'package:flowcraft/services/mcp_host.dart';
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
  // `renderPng` (flowcraft_screenshot) needs a live engine binding, whose
  // test HttpOverrides would answer every real request with a 400 — the
  // server under test is real, so those overrides are lifted again.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

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
        'flowcraft_diagram',
        'flowcraft_update',
        'flowcraft_delete',
        'flowcraft_clear',
        'flowcraft_screenshot',
        'flowcraft_guide',
        'flowcraft_checkpoint',
        'flowcraft_project',
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

    group('arrow bindings and reframe over MCP', () {
      Future<Map<String, dynamic>> call(
        String name,
        Map<String, dynamic> args,
      ) => rpc(
        'tools/call',
        params: {'name': name, 'arguments': args},
      ).then((b) => b['result'] as Map<String, dynamic>);

      SketchRectangle addBox() {
        final box = SketchRectangle.create(
          rect: const Rect.fromLTWH(200, 0, 100, 100),
        );
        controller.add(box);
        return box;
      }

      test('toId binds the end and the tip lands on the edge', () async {
        final box = addBox();
        final result = await call('flowcraft_draw', {
          'elements': [
            {'type': 'arrow', 'fromX': 0, 'fromY': 50, 'toId': box.id},
          ],
        });

        expect(result['isError'], isFalse);
        final arrow = controller.elements.whereType<SketchArrow>().single;
        expect(arrow.endBinding?.elementId, box.id);
        expect(arrow.end.dx, closeTo(200, 0.5));
        expect(arrow.end.dx, isNot(250));
        // Reply lists the new id.
        final text = ((result['content'] as List).single as Map)['text'];
        expect(text, contains('Element ids, in order: ${arrow.id}'));
      });

      test('update that moves the box re-routes the bound arrow', () async {
        final box = addBox();
        await call('flowcraft_draw', {
          'elements': [
            {'type': 'arrow', 'fromX': 0, 'fromY': 50, 'toId': box.id},
          ],
        });
        await call('flowcraft_update', {
          'elements': [
            {'id': box.id, 'x': 400},
          ],
        });

        final arrow = controller.elements.whereType<SketchArrow>().single;
        expect(arrow.end.dx, closeTo(400, 0.5));
      });

      test('unknown toId is a tool error', () async {
        final result = await call('flowcraft_draw', {
          'elements': [
            {'type': 'arrow', 'toId': 'nope'},
          ],
        });
        expect(result['isError'], isTrue);
        expect(controller.elements, isEmpty);
      });

      test('read shows fromId/toId', () async {
        final box = addBox();
        await call('flowcraft_draw', {
          'elements': [
            {'type': 'arrow', 'fromX': 0, 'fromY': 50, 'toId': box.id},
          ],
        });
        final read = await call('flowcraft_read', <String, dynamic>{});
        final json =
            jsonDecode(((read['content'] as List).single as Map)['text'])
                as Map<String, dynamic>;
        final arrow = (json['elements'] as List).cast<Map>().firstWhere(
          (e) => e['type'] == 'arrow',
        );
        expect(arrow['toId'], box.id);
        expect(arrow.containsKey('fromId'), isFalse);
      });

      test('draw and diagram request a frame, update does not', () async {
        final box = addBox();
        final gen0 = controller.frameRequestGen;
        await call('flowcraft_draw', {
          'elements': [
            {'type': 'rectangle', 'x': 0, 'y': 0},
          ],
        });
        expect(controller.frameRequestGen, gen0 + 1);
        expect(controller.frameRequest?.onlyIfHidden, isTrue);

        await call('flowcraft_diagram', {
          'nodes': [
            {'id': 'a'},
            {'id': 'b'},
          ],
          'edges': [
            {'from': 'a', 'to': 'b'},
          ],
        });
        expect(controller.frameRequestGen, gen0 + 2);

        await call('flowcraft_update', {
          'elements': [
            {'id': box.id, 'x': 5},
          ],
        });
        expect(controller.frameRequestGen, gen0 + 2);
      });

      test('diagram arrow tips end on node edges, not centres', () async {
        await call('flowcraft_diagram', {
          'nodes': [
            {'id': 'a'},
            {'id': 'b'},
          ],
          'edges': [
            {'from': 'a', 'to': 'b'},
          ],
        });
        final arrow = controller.elements.whereType<SketchArrow>().single;
        final boxes = {
          for (final e in controller.elements.whereType<SketchRectangle>())
            e.id: e.rect,
        };
        final from = boxes[arrow.startBinding!.elementId]!;
        final to = boxes[arrow.endBinding!.elementId]!;
        expect(from.center, isNot(arrow.start));
        expect(to.center, isNot(arrow.end));
        expect(from.inflate(1).contains(arrow.start), isTrue);
        expect(to.inflate(1).contains(arrow.end), isTrue);
        expect(from.deflate(1).contains(arrow.start), isFalse);
        expect(to.deflate(1).contains(arrow.end), isFalse);
      });
    });

    group('tools/call flowcraft_diagram', () {
      Future<Map<String, dynamic>> diagram(Map<String, dynamic> args) => rpc(
        'tools/call',
        params: {'name': 'flowcraft_diagram', 'arguments': args},
      ).then((b) => b['result'] as Map<String, dynamic>);

      Map<String, dynamic> payload(Map<String, dynamic> result) =>
          jsonDecode(
                ((result['content'] as List).single as Map)['text'] as String,
              )
              as Map<String, dynamic>;

      final abc = {
        'nodes': [
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'B'},
        ],
        'edges': [
          {'from': 'a', 'to': 'b'},
        ],
      };

      test('adds nodes and bound arrows and returns the key map', () async {
        final result = await diagram(abc);

        expect(result['isError'], isFalse);
        final json = payload(result);
        final nodes = (json['nodes'] as Map).cast<String, String>();
        expect(json['count'], 3);
        expect(controller.elements, hasLength(3));
        final arrow = controller.elements.whereType<SketchArrow>().single;
        expect(arrow.startBinding?.elementId, nodes['a']);
        expect(arrow.endBinding?.elementId, nodes['b']);
        expect(json['edges'], [arrow.id]);
      });

      test('mode=replace clears existing elements first', () async {
        controller.add(
          SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
        );

        await diagram({...abc, 'mode': 'replace'});

        expect(controller.elements, hasLength(3));
      });

      test('add mode places the diagram right of existing content', () async {
        controller.add(
          SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 500, 100)),
        );

        final json = payload(await diagram(abc));

        expect((json['bounds'] as Map)['x'], greaterThanOrEqualTo(500 + 96));
      });

      test('an invalid edge is a tool error and leaves the canvas', () async {
        controller.add(
          SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 10, 10)),
        );

        final result = await diagram({
          ...abc,
          'edges': [
            {'from': 'a', 'to': 'nope'},
          ],
        });

        expect(result['isError'], isTrue);
        expect(controller.elements, hasLength(1));
      });
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

    group('filtered flowcraft_read, screenshot, guide, checkpoints', () {
      Future<Map<String, dynamic>> call(
        String name, [
        Map<String, dynamic> arguments = const {},
      ]) async {
        final body = await rpc(
          'tools/call',
          params: {'name': name, 'arguments': arguments},
        );
        return body['result'] as Map<String, dynamic>;
      }

      Map<String, dynamic> jsonOf(Map<String, dynamic> result) =>
          jsonDecode((result['content'] as List).first['text'] as String)
              as Map<String, dynamic>;

      Future<void> drawThree() => call('flowcraft_draw', {
        'elements': [
          {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
          {'type': 'ellipse', 'x': 500, 'y': 0, 'width': 50, 'height': 50},
          {'type': 'rectangle', 'x': 1000, 'y': 0, 'width': 50, 'height': 50},
        ],
      });

      test('read filters by types', () async {
        await drawThree();

        final json = jsonOf(
          await call('flowcraft_read', {
            'types': ['ellipse'],
          }),
        );

        expect(json['total'], 1);
        expect((json['elements'] as List).single['type'], 'ellipse');
      });

      test('read filters by ids', () async {
        await drawThree();
        final all = jsonOf(await call('flowcraft_read'));
        final second = (all['elements'] as List)[1]['id'];

        final json = jsonOf(
          await call('flowcraft_read', {
            'ids': [second],
          }),
        );

        expect(json['total'], 1);
        expect((json['elements'] as List).single['id'], second);
      });

      test('read region intersects element bounds', () async {
        await drawThree();

        final json = jsonOf(
          await call('flowcraft_read', {
            'region': {'x': 490, 'y': 10, 'width': 30, 'height': 30},
          }),
        );

        expect(json['total'], 1);
        expect((json['elements'] as List).single['type'], 'ellipse');
      });

      test('read pages with limit, offset and nextOffset', () async {
        await drawThree();

        final first = jsonOf(await call('flowcraft_read', {'limit': 2}));
        expect(first['total'], 3);
        expect(first['count'], 2);
        expect(first['nextOffset'], 2);

        final last = jsonOf(
          await call('flowcraft_read', {'limit': 2, 'offset': 2}),
        );
        expect((last['elements'] as List).length, 1);
        expect(last.containsKey('nextOffset'), isFalse);
      });

      test('read rejects wrongly typed filters instead of crashing', () async {
        final result = await call('flowcraft_read', {'types': 'rectangle'});

        expect(result['isError'], isTrue);
      });

      test(
        'screenshot returns an image block starting with PNG magic bytes',
        () async {
          await drawThree();

          final result = await call('flowcraft_screenshot', {'maxSide': 400});

          expect(result['isError'], isFalse);
          final image = (result['content'] as List).first as Map;
          expect(image['type'], 'image');
          expect(image['mimeType'], 'image/png');
          final bytes = base64Decode(image['data'] as String);
          expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );

      test('screenshot of an empty selection fails', () async {
        final result = await call('flowcraft_screenshot');

        expect(result['isError'], isTrue);
      });

      test(
        'guide returns the requested topic and rejects unknown ones',
        () async {
          final layout = await call('flowcraft_guide', {'topic': 'layout'});
          expect(
            (layout['content'] as List).single['text'],
            contains('260x120'),
          );

          final bad = await call('flowcraft_guide', {'topic': 'nope'});
          expect(bad['isError'], isTrue);
        },
      );

      test(
        'draw → list shows cp-1 → restore brings scene back and canUndo is true',
        () async {
          await drawThree();

          final listed = jsonOf(
            await call('flowcraft_checkpoint', {'action': 'list'}),
          );
          final cps = listed['checkpoints'] as List;
          expect(cps.single['id'], 'cp-1');
          expect(cps.single['elementCount'], 0);

          final restored = await call('flowcraft_checkpoint', {
            'action': 'restore',
            'id': 'cp-1',
          });

          expect(restored['isError'], isFalse);
          expect(controller.elements, isEmpty);
          // History-tracked, so Ctrl+Z in the app undoes the restore.
          expect(controller.canUndo, isTrue);
        },
      );

      test('restoring an unknown checkpoint fails', () async {
        final result = await call('flowcraft_checkpoint', {
          'action': 'restore',
          'id': 'cp-99',
        });

        expect(result['isError'], isTrue);
      });
    });
  });

  group('flowcraft_project', () {
    late _FakeHost host;
    late FlowcraftControlServer withHost;
    late Uri hostBase;

    setUp(() async {
      host = _FakeHost(controller);
      withHost = FlowcraftControlServer(
        controller: controller,
        port: 0,
        configDir: tempConfigDir,
        projects: host.asHost,
      );
      await withHost.start();
      hostBase = Uri.parse('http://127.0.0.1:${withHost.boundPort}/mcp');
    });

    tearDown(() => withHost.stop());

    Future<Map<String, dynamic>> project(
      Map<String, dynamic> args, {
      Uri? at,
    }) async {
      final request = await client.postUrl(at ?? hostBase);
      request.headers.contentType = ContentType.json;
      request.headers.set('X-Flowcraft-Token', withHost.token);
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': 'flowcraft_project', 'arguments': args},
        }),
      );
      final response = await request.close();
      final body = await readJson(response);
      return body['result'] as Map<String, dynamic>;
    }

    String textOf(Map<String, dynamic> r) =>
        (r['content'] as List).single['text'] as String;

    test('list JSON', () async {
      final result = await project({'action': 'list'});

      final projects = (jsonDecode(textOf(result)) as Map)['projects'] as List;
      expect(projects.map((p) => p['name']), ['Alpha', 'Beta']);
      expect(projects.first['active'], isTrue);
    });

    test('open by name switches activeId and frames', () async {
      final gen = controller.frameRequestGen;

      final result = await project({'action': 'open', 'name': 'beta'});

      expect(result['isError'], isFalse);
      expect(host.active, 'p2');
      expect(controller.frameRequestGen, greaterThan(gen));
    });

    test('ambiguous name fails', () async {
      host.projects.add(_project('p3', 'Beta'));

      final result = await project({'action': 'open', 'name': 'Beta'});

      expect(result['isError'], isTrue);
      expect(textOf(result), contains('p2'));
      expect(host.active, 'p1');
    });

    test('create and rename go through the host', () async {
      final created = await project({'action': 'create', 'name': 'Gamma'});
      expect(created['isError'], isFalse);
      expect(host.projects.last.name, 'Gamma');
      expect(host.active, host.projects.last.id);

      final renamed = await project({
        'action': 'rename',
        'id': 'p1',
        'name': 'Alpha 2',
      });
      expect(renamed['isError'], isFalse);
      expect(host.projects.first.name, 'Alpha 2');
    });

    test('wrongly typed arguments fail cleanly', () async {
      final result = await project({'action': 'open', 'id': 7});

      expect(result['isError'], isTrue);
    });

    test('a checkpoint from another project is refused', () async {
      // The host's active project is p1 while this draw is checkpointed.
      await project({'action': 'list'});
      final draw = await client.postUrl(hostBase);
      draw.headers.contentType = ContentType.json;
      draw.headers.set('X-Flowcraft-Token', withHost.token);
      draw.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {
            'name': 'flowcraft_draw',
            'arguments': {
              'elements': [
                {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 5, 'height': 5},
              ],
            },
          },
        }),
      );
      await (await draw.close()).drain<void>();
      await project({'action': 'open', 'id': 'p2'});

      final request = await client.postUrl(hostBase);
      request.headers.contentType = ContentType.json;
      request.headers.set('X-Flowcraft-Token', withHost.token);
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {
            'name': 'flowcraft_checkpoint',
            'arguments': {'action': 'restore', 'id': 'cp-1'},
          },
        }),
      );
      final body = await readJson(await request.close());

      final result = body['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('another project'));
    });

    test('no host → unavailable', () async {
      final result = await project({
        'action': 'list',
      }, at: base.replace(path: '/mcp'));

      expect(result['isError'], isTrue);
      expect(textOf(result), contains('unavailable'));
    });
  });
}

FlowProject _project(String id, String name) => FlowProject(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  elementCount: 0,
);

/// In-memory stand-in for the closures `McpViewModel` wires onto
/// `ProjectsViewModel`: opening loads a one-rectangle scene, as a real open
/// would load the saved one.
class _FakeHost {
  _FakeHost(this._controller);

  final SketchController _controller;
  final List<FlowProject> projects = [
    _project('p1', 'Alpha'),
    _project('p2', 'Beta'),
  ];
  String? active = 'p1';

  McpProjectsHost get asHost => McpProjectsHost(
    list: () => List.of(projects),
    activeId: () => active,
    open: (id) async {
      active = id;
      _controller.loadScene([
        SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 100, 50)),
      ]);
    },
    create: (name) async {
      final p = _project('p${projects.length + 1}', name);
      projects.add(p);
      active = p.id;
      _controller.loadScene(const []);
    },
    rename: (id, name) async {
      final i = projects.indexWhere((p) => p.id == id);
      projects[i] = projects[i].copyWith(name: name);
    },
  );
}
