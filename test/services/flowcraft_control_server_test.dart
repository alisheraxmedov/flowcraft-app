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
}
