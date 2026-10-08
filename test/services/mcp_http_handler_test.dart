import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/services/mcp_http_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constantTimeEquals', () {
    const token = 'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5';

    test('accepts the real token', () {
      expect(constantTimeEquals(token, token), isTrue);
      // A fresh string, so this cannot be passing on identity alone.
      expect(
        constantTimeEquals(String.fromCharCodes(token.codeUnits), token),
        isTrue,
      );
    });

    test('rejects wrong candidates whatever their length', () {
      for (final wrong in [
        '', // empty
        'x', // far too short
        token.substring(0, token.length - 1), // a correct prefix
        '$token=', // the token plus a byte
        '${token.substring(0, token.length - 1)}X', // one byte off at the end
        'X${token.substring(1)}', // one byte off at the start
        'x' * 4096, // far too long
      ]) {
        expect(
          constantTimeEquals(wrong, token),
          isFalse,
          reason: 'accepted a ${wrong.length}-byte candidate',
        );
      }
    });

    test('is symmetric and handles two empty strings', () {
      expect(constantTimeEquals('', ''), isTrue);
      expect(constantTimeEquals('a', ''), isFalse);
      expect(constantTimeEquals('', 'a'), isFalse);
    });

    test('compares bytes, not code units', () {
      // Same length in characters, different length in UTF-8.
      expect(constantTimeEquals('é', 'e'), isFalse);
    });
  });

  group('body limits', () {
    test('the cap is generous enough for a real diagram', () {
      // A wordy element serializes to a few hundred bytes; the cap has to
      // clear a full-size draw call by a wide margin or it becomes a bug
      // report instead of a guardrail.
      expect(maxRequestBodyBytes, greaterThan(10000 * 300));
    });

    test('the exception names the limit and nothing else', () {
      expect(
        const RequestBodyTooLargeException().toString(),
        'request body exceeds the $maxRequestBodyBytes byte limit',
      );
    });
  });

  // The read/edit surface is exercised against a real McpHttpHandler driven
  // over a loopback HttpServer — no full control server needed, just the
  // handler, a live SketchController and a token, the way the class is meant
  // to be wired.
  group('read / update / delete tools', () {
    late SketchController controller;
    late HttpServer httpServer;
    late HttpClient client;
    late Uri endpoint;
    const token = 'test-token';

    setUp(() async {
      controller = SketchController(currentTool: SketchTool.select);
      final handler = McpHttpHandler(controller: controller, token: token);
      httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen(handler.handle);
      endpoint = Uri.parse('http://127.0.0.1:${httpServer.port}/mcp');
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await httpServer.close(force: true);
      controller.dispose();
    });

    Future<Map<String, dynamic>> rpc(
      String method, {
      Map<String, dynamic>? params,
    }) async {
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.headers.set(McpHttpHandler.tokenHeader, token);
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': ?params,
        }),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    }

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

    String textOf(Map<String, dynamic> result) =>
        (result['content'] as List).single['text'] as String;

    test(
      'tools/list carries read, update and delete with usable schemas',
      () async {
        final body = await rpc('tools/list');
        final tools = (body['result'] as Map<String, dynamic>)['tools'] as List;
        final byName = {
          for (final t in tools) (t as Map<String, dynamic>)['name']: t,
        };

        expect(
          byName.keys,
          containsAll([
            'flowcraft_read',
            'flowcraft_update',
            'flowcraft_delete',
          ]),
        );

        final read = byName['flowcraft_read'] as Map<String, dynamic>;
        expect((read['inputSchema'] as Map<String, dynamic>)['type'], 'object');

        final update = byName['flowcraft_update'] as Map<String, dynamic>;
        final updateSchema = update['inputSchema'] as Map<String, dynamic>;
        expect(updateSchema['required'], ['elements']);
        final items =
            ((updateSchema['properties'] as Map<String, dynamic>)['elements']
                    as Map<String, dynamic>)['items']
                as Map<String, dynamic>;
        expect(items['required'], ['id']);
        expect(
          (items['properties'] as Map<String, dynamic>).keys,
          // The id addresses the element; the rest is the draw vocabulary.
          containsAll([
            'id',
            'type',
            'x',
            'y',
            'width',
            'height',
            'fromX',
            'toY',
            'text',
            'fontSize',
            'strokeColor',
            'fillColor',
          ]),
        );

        final del = byName['flowcraft_delete'] as Map<String, dynamic>;
        final delSchema = del['inputSchema'] as Map<String, dynamic>;
        expect(delSchema['required'], ['ids']);
        expect(
          ((delSchema['properties'] as Map<String, dynamic>)['ids']
              as Map<String, dynamic>)['type'],
          'array',
        );
      },
    );

    test('flowcraft_read returns every element with id and geometry', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(10, 20, 200, 80),
          text: 'A',
        ),
      );
      controller.add(
        SketchArrow.create(
          id: 'a1',
          start: const Offset(0, 0),
          end: const Offset(50, 60),
        ),
      );

      final result = await call('flowcraft_read');
      expect(result['isError'], isFalse);
      final decoded = jsonDecode(textOf(result)) as Map<String, dynamic>;
      expect(decoded['count'], 2);

      final elements = (decoded['elements'] as List)
          .cast<Map<String, dynamic>>();
      final rect = elements.firstWhere((e) => e['id'] == 'r1');
      expect(rect['type'], 'rectangle');
      expect(rect['x'], 10);
      expect(rect['width'], 200);
      expect(rect['text'], 'A');
      final arrow = elements.firstWhere((e) => e['id'] == 'a1');
      expect(arrow['type'], 'arrow');
      expect(arrow['fromX'], 0);
      expect(arrow['toY'], 60);
    });

    test('flowcraft_update changes only the targeted element', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 100, 50),
          text: 'A',
        ),
      );
      controller.add(
        SketchRectangle.create(
          id: 'r2',
          rect: const Rect.fromLTWH(200, 0, 100, 50),
          text: 'B',
        ),
      );

      final result = await call('flowcraft_update', {
        'elements': [
          {'id': 'r1', 'x': 20, 'text': 'Renamed', 'strokeColor': '#FF0000'},
        ],
      });
      expect(result['isError'], isFalse);
      expect(textOf(result), contains('Updated 1'));

      final r1 =
          controller.elements.firstWhere((e) => e.id == 'r1')
              as SketchRectangle;
      expect(r1.rect.left, 20);
      expect(r1.rect.width, 100); // unspecified — left as it was
      expect(r1.text, 'Renamed');
      expect(r1.style.strokeColor, const Color(0xFFFF0000));

      final r2 =
          controller.elements.firstWhere((e) => e.id == 'r2')
              as SketchRectangle;
      expect(r2.rect.left, 200);
      expect(r2.text, 'B');
    });

    test('flowcraft_update reports ids that are not on the canvas', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );

      final result = await call('flowcraft_update', {
        'elements': [
          {'id': 'r1', 'x': 5},
          {'id': 'ghost', 'x': 9},
        ],
      });
      expect(result['isError'], isFalse);
      expect(textOf(result), allOf(contains('Updated 1'), contains('ghost')));
    });

    test('flowcraft_update with no matching id is a tool error', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );

      final result = await call('flowcraft_update', {
        'elements': [
          {'id': 'ghost', 'x': 9},
        ],
      });
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('ghost'));
    });

    test('flowcraft_update surfaces a bad patch as a targeted error', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );

      final result = await call('flowcraft_update', {
        'elements': [
          {'id': 'r1', 'type': 'ellipse'},
        ],
      });
      expect(result['isError'], isTrue);
      expect(textOf(result), allOf(contains('r1'), contains('type')));
    });

    test('flowcraft_delete removes by id and leaves the rest', () async {
      controller.add(
        SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );
      controller.add(
        SketchRectangle.create(
          id: 'r2',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );

      final result = await call('flowcraft_delete', {
        'ids': ['r1', 'ghost'],
      });
      expect(result['isError'], isFalse);
      expect(textOf(result), allOf(contains('Deleted 1'), contains('ghost')));
      expect(controller.elements.map((e) => e.id), ['r2']);
    });
  });

  // Custom tools exercise the handler's plumbing (awaiting, content blocks,
  // checkpoint-before-mutation) without depending on any real tool.
  group('tool plumbing', () {
    late SketchController controller;
    late HttpServer httpServer;
    late HttpClient client;
    const token = 'test-token';

    Future<Map<String, dynamic>> callWith(List<McpTool> tools) async {
      controller = SketchController(currentTool: SketchTool.select);
      final handler = McpHttpHandler(
        controller: controller,
        token: token,
        tools: tools,
      );
      httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      httpServer.listen(handler.handle);
      client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${httpServer.port}/mcp'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(McpHttpHandler.tokenHeader, token);
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': 't', 'arguments': <String, dynamic>{}},
        }),
      );
      final response = await request.close();
      final body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      return body['result'] as Map<String, dynamic>;
    }

    tearDown(() async {
      client.close(force: true);
      await httpServer.close(force: true);
      controller.dispose();
    });

    test('async tool is awaited', () async {
      final result = await callWith([
        McpTool(
          name: 't',
          description: '',
          inputSchema: const {'type': 'object'},
          run: (ctx, args) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const McpToolResult('late answer');
          },
        ),
      ]);

      expect((result['content'] as List).single['text'], 'late answer');
      expect(result['isError'], isFalse);
    });

    test('image result serialises as an image content block', () async {
      final result = await callWith([
        McpTool(
          name: 't',
          description: '',
          inputSchema: const {'type': 'object'},
          run: (ctx, args) =>
              McpToolResult.image(Uint8List.fromList([1, 2, 3]), text: 'cap'),
        ),
      ]);

      final content = result['content'] as List;
      expect(content.first, {
        'type': 'image',
        'data': base64Encode([1, 2, 3]),
        'mimeType': 'image/png',
      });
      expect(content.last, {'type': 'text', 'text': 'cap'});
    });

    test('a mutating tool is checkpointed before it runs', () async {
      late int sceneSizeSeenByTool;
      final result = await callWith([
        McpTool(
          name: 't',
          description: '',
          inputSchema: const {'type': 'object'},
          mutates: true,
          run: (ctx, args) {
            sceneSizeSeenByTool = ctx.checkpoints.list().length;
            return const McpToolResult('ok');
          },
        ),
      ]);

      expect(result['isError'], isFalse);
      expect(sceneSizeSeenByTool, 1);
    });
  });
}
