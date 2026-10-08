import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/services/image_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real PNG, 3 wide by 2 tall.
Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 3, 2),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(3, 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('fc_img_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> expectRefused(Map<String, Object?> entry, [String? contains]) {
    return expectLater(
      ImageSource.resolve([entry]),
      throwsA(
        isA<DiagramSpecException>().having(
          (e) => e.message,
          'message',
          contains == null ? isNotEmpty : stringContainsInOrder([contains]),
        ),
      ),
    );
  }

  test('dataUrl resolves with natural size', () async {
    final png = await _png();
    final out = await ImageSource.resolve([
      {
        'type': 'image',
        'x': 4,
        'dataUrl': 'data:image/png;base64,${base64Encode(png)}',
      },
    ]);
    final m = out.single as Map;
    expect(m['mimeType'], 'image/png');
    expect(m['data'], base64Encode(png));
    expect(m['width'], 3);
    expect(m['height'], 2);
    expect(m.containsKey('dataUrl'), isFalse);
    expect(m['x'], 4);
    // And the parser accepts the result.
    expect(parseDiagramElements(out).single, isA<SketchImage>());
  });

  test('one given dimension keeps the aspect ratio', () async {
    final png = await _png();
    final out = await ImageSource.resolve([
      {
        'type': 'image',
        'width': 30,
        'dataUrl': 'data:image/png;base64,${base64Encode(png)}',
      },
    ]);
    expect((out.single as Map)['height'], 20);
  });

  test('path to a temp PNG resolves', () async {
    final png = await _png();
    final file = File('${tempDir.path}/pic.PNG')..writeAsBytesSync(png);
    final out = await ImageSource.resolve([
      {'type': 'image', 'path': file.path, 'width': 9, 'height': 9},
    ]);
    final m = out.single as Map;
    expect(m['mimeType'], 'image/png');
    expect(base64Decode(m['data'] as String), png);
    expect(m['width'], 9);
    expect(m.containsKey('path'), isFalse);
  });

  test('non-image entries pass through untouched', () async {
    final rect = {'type': 'rectangle', 'text': 'x'};
    expect(await ImageSource.resolve([rect]), [rect]);
  });

  test(
    'relative path / bad extension / too large / directory refused',
    () async {
      await expectRefused({'type': 'image', 'path': 'pic.png'}, 'absolute');
      final txt = File('${tempDir.path}/a.txt')..writeAsStringSync('x');
      await expectRefused({'type': 'image', 'path': txt.path}, 'must end in');
      final big = File('${tempDir.path}/big.png')
        ..writeAsBytesSync(Uint8List(maxImageBytes + 1));
      await expectRefused({'type': 'image', 'path': big.path}, 'limit');
      final dir = Directory('${tempDir.path}/d.png')..createSync();
      await expectRefused({'type': 'image', 'path': dir.path}, 'regular file');
      await expectRefused({
        'type': 'image',
        'path': '${tempDir.path}/none.png',
      }, 'does not exist');
    },
  );

  test('symlink refused', () async {
    final png = await _png();
    final real = File('${tempDir.path}/real.png')..writeAsBytesSync(png);
    final link = Link('${tempDir.path}/link.png')..createSync(real.path);
    await expectRefused({'type': 'image', 'path': link.path}, 'regular file');
  });

  test('bad dataUrl refused', () async {
    await expectRefused({'type': 'image', 'dataUrl': 'nope'});
    await expectRefused({
      'type': 'image',
      'dataUrl': 'data:image/svg+xml;base64,AA==',
    });
  });
}
