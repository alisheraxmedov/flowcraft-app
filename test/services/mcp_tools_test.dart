import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/services/mcp_guide.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1x1 PNG, so "natural size" is a known 1x1.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==';
const _pngMagic = [0x89, 0x50, 0x4E, 0x47];

void main() {
  // The image tools need a live engine binding, whose test HttpOverrides
  // would answer the (real) server's requests with a 400.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late Directory tempDir;
  late SketchController controller;
  late FlowcraftControlServer server;
  late HttpClient client;
  late Uri base;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('flowcraft_tools_');
    controller = SketchController(currentTool: SketchTool.select);
    server = FlowcraftControlServer(
      controller: controller,
      port: 0,
      configDir: Directory('${tempDir.path}/config')..createSync(),
    );
    await server.start();
    base = Uri.parse('http://127.0.0.1:${server.boundPort}');
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    controller.dispose();
    tempDir.deleteSync(recursive: true);
  });

  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final request = await client.postUrl(base.replace(path: '/mcp'));
    request.headers.contentType = ContentType.json;
    request.headers.set('X-Flowcraft-Token', server.token);
    request.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': ?params,
      }),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// The `result` of one tool call.
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> args = const {},
  ]) async {
    final r = await rpc('tools/call', {'name': name, 'arguments': args});
    return r['result'] as Map<String, dynamic>;
  }

  String textOf(Map<String, dynamic> result) =>
      (result['content'] as List).cast<Map>().firstWhere(
            (c) => c['type'] == 'text',
          )['text']
          as String;

  Map<String, dynamic> jsonOf(Map<String, dynamic> result) =>
      jsonDecode(textOf(result)) as Map<String, dynamic>;

  Future<List<Map>> readElements([Map<String, dynamic> args = const {}]) async {
    final r = await call('flowcraft_read', args);
    expect(r['isError'], isFalse, reason: textOf(r));
    return (jsonOf(r)['elements'] as List).cast<Map>();
  }

  Map<String, dynamic> imageEntry(Map<String, dynamic> extra) => {
    'type': 'image',
    'x': 10,
    'y': 20,
    ...extra,
  };

  group('draw: new vocabulary', () {
    test('an image from a dataUrl takes its natural size', () async {
      final r = await call('flowcraft_draw', {
        'elements': [
          imageEntry({'dataUrl': 'data:image/png;base64,$_pngBase64'}),
        ],
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      final image = controller.elements.single as SketchImage;
      expect(image.rect.size, const Size(1, 1));
      expect(image.mimeType, 'image/png');
    });

    test('an image from a temp-file path', () async {
      final file = File('${tempDir.path}/pic.png')
        ..writeAsBytesSync(base64Decode(_pngBase64));
      final r = await call('flowcraft_draw', {
        'elements': [
          imageEntry({'path': file.path, 'width': 40}),
        ],
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      final image = controller.elements.single as SketchImage;
      expect(image.rect.width, 40);
      expect(image.rect.height, 40); // 1:1 aspect kept
    });

    test('an arrow with toAttribute binds to the entity row', () async {
      await call('flowcraft_draw', {
        'elements': [
          {
            'type': 'entity',
            'x': 0,
            'y': 0,
            'width': 200,
            'name': 'users',
            'attributes': [
              {'name': 'id', 'type': 'int', 'pk': true},
              {'name': 'email', 'type': 'text'},
            ],
          },
        ],
      });
      final entity = controller.elements.single as SketchEntity;
      final r = await call('flowcraft_draw', {
        'elements': [
          {
            'type': 'arrow',
            'fromX': 400,
            'fromY': 50,
            'toX': 200,
            'toY': 50,
            'toId': entity.id,
            'toAttribute': 'email',
            'endHead': 'many',
          },
        ],
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      final arrow = controller.elements.whereType<SketchArrow>().single;
      expect(arrow.endBinding?.elementId, entity.id);
      expect(arrow.endBinding?.attribute, 'email');
      expect(arrow.endHead, ArrowheadStyle.many);
    });

    test('a frame lands behind everything else in its batch', () async {
      await call('flowcraft_draw', {
        'elements': [
          {'type': 'rectangle', 'x': 20, 'y': 20, 'width': 50, 'height': 50},
          {
            'type': 'frame',
            'x': 0,
            'y': 0,
            'width': 200,
            'height': 200,
            'name': 'Box',
          },
        ],
      });
      expect(controller.elements.first, isA<SketchFrame>());
      expect(controller.elements.length, 2);
    });

    test('draw bumps revealGen and frameRequestGen', () async {
      final reveal = controller.revealGen, frame = controller.frameRequestGen;
      await call('flowcraft_draw', {
        'elements': [
          {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
        ],
      });
      expect(controller.revealGen, reveal + 1);
      expect(controller.frameRequestGen, frame + 1);
    });
  });

  group('read', () {
    Future<void> drawImage() => call('flowcraft_draw', {
      'elements': [
        imageEntry({'dataUrl': 'data:image/png;base64,$_pngBase64'}),
      ],
    });

    test('omits image data by default', () async {
      await drawImage();
      final image = (await readElements()).single;
      expect(image.containsKey('data'), isFalse);
      expect(image['mimeType'], 'image/png');
      expect(image['width'], 1);
      expect(image['height'], 1);
      expect(image['bytes'], base64Decode(_pngBase64).length);
    });

    test('includeImageData brings the bytes back', () async {
      await drawImage();
      final image = (await readElements({'includeImageData': true})).single;
      expect(image['data'], _pngBase64);
    });
  });

  group('frame filter', () {
    setUp(() async {
      await call('flowcraft_draw', {
        'elements': [
          {
            'type': 'frame',
            'x': 0,
            'y': 0,
            'width': 300,
            'height': 300,
            'name': 'Box',
          },
          {'type': 'rectangle', 'x': 10, 'y': 10, 'width': 50, 'height': 50},
          {'type': 'rectangle', 'x': 500, 'y': 500, 'width': 50, 'height': 50},
        ],
      });
    });

    test('read returns the frame and its members, by name or id', () async {
      final byName = await readElements({'frame': 'box'});
      expect(byName.map((e) => e['type']), ['frame', 'rectangle']);
      final frameId = controller.elements.first.id;
      expect(await readElements({'frame': frameId}), hasLength(2));
    });

    test('screenshot and export honour it', () async {
      final shot = await call('flowcraft_screenshot', {'frame': 'Box'});
      expect(shot['isError'], isFalse, reason: jsonEncode(shot));
      expect(
        base64Decode(
          (shot['content'] as List).cast<Map>().first['data'] as String,
        ).take(4),
        _pngMagic,
      );
      final export = await call('flowcraft_export', {
        'format': 'json',
        'frame': 'Box',
      });
      expect(jsonOf(export)['elements'], hasLength(2));
    });

    test('an unknown frame fails everywhere', () async {
      for (final tool in ['flowcraft_read', 'flowcraft_screenshot']) {
        final r = await call(tool, {'frame': 'Nope'});
        expect(r['isError'], isTrue, reason: tool);
        expect(textOf(r), contains('Nope'));
      }
      final r = await call('flowcraft_export', {
        'format': 'svg',
        'frame': 'Nope',
      });
      expect(r['isError'], isTrue);
    });
  });

  group('flowcraft_import', () {
    test('mermaid flowchart: nodes, bound arrows, subgraph frame', () async {
      final r = await call('flowcraft_import', {
        'text':
            'flowchart LR\n  a[Client] --> b[Server]\n  subgraph Back\n'
            '    b\n  end\n',
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(jsonOf(r)['dropped'], 0);
      expect(controller.elements.first, isA<SketchFrame>());
      expect((controller.elements.first as SketchFrame).name, 'Back');
      expect(controller.elements.whereType<SketchRectangle>(), hasLength(2));
      final arrow = controller.elements.whereType<SketchArrow>().single;
      expect(arrow.startBinding, isNotNull);
      expect(arrow.endBinding, isNotNull);
    });

    test('mermaid erDiagram: entities with crow\'s-foot heads', () async {
      final r = await call('flowcraft_import', {
        'text':
            'erDiagram\n  USER ||--o{ ORDER : places\n  USER {\n    int id PK\n'
            '  }\n',
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(controller.elements.whereType<SketchEntity>(), hasLength(2));
      final arrow = controller.elements.whereType<SketchArrow>().single;
      expect(arrow.startHead, ArrowheadStyle.one);
      expect(arrow.endHead, ArrowheadStyle.zeroOrMany);
    });

    test('DBML tables and refs', () async {
      final r = await call('flowcraft_import', {
        'text':
            'Table users {\n  id int [pk]\n}\nTable posts {\n  id int [pk]\n'
            '  user_id int [ref: > users.id]\n}\n',
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(controller.elements.whereType<SketchEntity>(), hasLength(2));
      expect(controller.elements.whereType<SketchArrow>(), hasLength(1));
    });

    test('excalidraw reports what it dropped', () async {
      final r = await call('flowcraft_import', {
        'text': jsonEncode({
          'type': 'excalidraw',
          'version': 2,
          'elements': [
            {
              'id': 'r1',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 50,
            },
            {
              'id': 'f1',
              'type': 'frame',
              'x': 0,
              'y': 0,
              'width': 10,
              'height': 10,
            },
          ],
        }),
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(jsonOf(r)['count'], 1);
      expect(jsonOf(r)['dropped'], 1);
      expect(controller.elements.single, isA<SketchRectangle>());
    });

    test('a FlowCraft json scene round-trips through add mode', () async {
      await call('flowcraft_draw', {
        'elements': [
          {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
        ],
      });
      final scene = jsonOf(await call('flowcraft_export', {'format': 'json'}));
      final r = await call('flowcraft_import', {'text': jsonEncode(scene)});
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(controller.elements, hasLength(2));
      expect(controller.elements.map((e) => e.id).toSet(), hasLength(2));
    });

    test(
      'a bad line fails with its number and leaves the canvas alone',
      () async {
        await call('flowcraft_draw', {
          'elements': [
            {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
          ],
        });
        final before = controller.elements.map((e) => e.id).toList();
        final r = await call('flowcraft_import', {
          'text': 'flowchart LR\n  a --> b\n  ??? nonsense\n',
        });
        expect(r['isError'], isTrue);
        expect(textOf(r), contains('line 3'));
        expect(controller.elements.map((e) => e.id).toList(), before);
      },
    );

    test('replace mode clears the canvas first', () async {
      await call('flowcraft_draw', {
        'elements': [
          {'type': 'rectangle', 'x': 0, 'y': 0, 'width': 50, 'height': 50},
        ],
      });
      final old = controller.elements.single.id;
      final r = await call('flowcraft_import', {
        'text': 'flowchart TB\n  a --> b\n',
        'mode': 'replace',
      });
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(controller.elements.any((e) => e.id == old), isFalse);
      expect(controller.elements, hasLength(3)); // two boxes + one arrow
    });

    test('import bumps revealGen and frameRequestGen', () async {
      final reveal = controller.revealGen, frame = controller.frameRequestGen;
      await call('flowcraft_import', {'text': 'flowchart TB\n  a --> b\n'});
      expect(controller.revealGen, reveal + 1);
      expect(controller.frameRequestGen, frame + 1);
    });
  });

  group('flowcraft_export', () {
    setUp(() async {
      await call('flowcraft_draw', {
        'elements': [
          {
            'type': 'rectangle',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 60,
            'text': 'Hi',
          },
        ],
      });
    });

    test('png inline is an image block', () async {
      final r = await call('flowcraft_export', {'format': 'png'});
      expect(r['isError'], isFalse, reason: jsonEncode(r));
      final block = (r['content'] as List).cast<Map>().first;
      expect(block['type'], 'image');
      expect(base64Decode(block['data'] as String).take(4), _pngMagic);
    });

    test('svg inline starts with <svg', () async {
      final r = await call('flowcraft_export', {'format': 'svg'});
      expect(textOf(r), startsWith('<svg'));
    });

    test('json inline parses as a scene', () async {
      final r = await call('flowcraft_export', {'format': 'json'});
      expect(jsonOf(r)['elements'], hasLength(1));
    });

    test('png to a temp dir writes a PNG file', () async {
      final path = '${tempDir.path}/out.png';
      final r = await call('flowcraft_export', {'format': 'png', 'path': path});
      expect(r['isError'], isFalse, reason: textOf(r));
      expect(jsonOf(r)['format'], 'png');
      expect(File(path).readAsBytesSync().take(4), _pngMagic);
    });

    test('refuses a path whose extension does not match', () async {
      final r = await call('flowcraft_export', {
        'format': 'png',
        'path': '${tempDir.path}/out.txt',
      });
      expect(r['isError'], isTrue);
      expect(textOf(r), contains('.png'));
      expect(File('${tempDir.path}/out.txt').existsSync(), isFalse);
    });

    test('refuses an existing file unless overwrite is set', () async {
      final path = '${tempDir.path}/out.svg';
      File(path).writeAsStringSync('old');
      final refused = await call('flowcraft_export', {
        'format': 'svg',
        'path': path,
      });
      expect(refused['isError'], isTrue);
      expect(textOf(refused), contains('overwrite'));
      expect(File(path).readAsStringSync(), 'old');
      final ok = await call('flowcraft_export', {
        'format': 'svg',
        'path': path,
        'overwrite': true,
      });
      expect(ok['isError'], isFalse, reason: textOf(ok));
      expect(File(path).readAsStringSync(), startsWith('<svg'));
    });

    test('refuses a path under ~/.flowcraft', () async {
      final home = Platform.environment['HOME'] ?? tempDir.path;
      final r = await call('flowcraft_export', {
        'format': 'json',
        'path': '$home/.flowcraft/export_test.json',
      });
      // Whether ~/.flowcraft exists on this machine decides which rule
      // fires first; either way nothing may be written there.
      expect(r['isError'], isTrue);
      expect(File('$home/.flowcraft/export_test.json').existsSync(), isFalse);
    });

    test('an empty selection fails', () async {
      final r = await call('flowcraft_export', {
        'format': 'png',
        'types': ['ellipse'],
      });
      expect(r['isError'], isTrue);
    });
  });

  group('schemas', () {
    test('tools/list order', () async {
      final r = await rpc('tools/list');
      final names = ((r['result'] as Map)['tools'] as List)
          .map((t) => (t as Map)['name'])
          .toList();
      expect(names, [
        'flowcraft_status',
        'flowcraft_read',
        'flowcraft_draw',
        'flowcraft_diagram',
        'flowcraft_import',
        'flowcraft_update',
        'flowcraft_delete',
        'flowcraft_clear',
        'flowcraft_screenshot',
        'flowcraft_export',
        'flowcraft_guide',
        'flowcraft_checkpoint',
        'flowcraft_project',
      ]);
    });

    test('hand-kept lists match their sources', () {
      expect(iconNamesText.split(', ').toSet(), iconCatalog.keys.toSet());
      final draw = flowcraftMcpTools.firstWhere(
        (t) => t.name == 'flowcraft_draw',
      );
      final head =
          ((draw.inputSchema['properties'] as Map)['elements'] as Map)['items']
              as Map;
      final heads =
          ((head['properties'] as Map)['startHead'] as Map)['enum'] as List;
      expect(heads, ArrowheadStyle.values.map((s) => s.name).toList());
      for (final name in iconCatalog.keys) {
        expect(mcpGuideText, contains(name));
      }
    });
  });
}
