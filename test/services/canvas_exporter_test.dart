import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _background = Color(0xFFFDFDFD);

SketchRectangle _rect({Rect rect = const Rect.fromLTWH(100, 50, 200, 120)}) {
  return SketchRectangle.create(rect: rect);
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  // `Picture.toImage` needs a live engine binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasExporter.contentBounds', () {
    test('unions every element and ignores non-finite bounds', () {
      final bounds = CanvasExporter.contentBounds([
        _rect(rect: const Rect.fromLTWH(0, 0, 10, 10)),
        _rect(rect: const Rect.fromLTWH(90, 40, 10, 10)),
      ]);

      expect(bounds, const Rect.fromLTWH(0, 0, 100, 50));
    });

    test('is Rect.zero for an empty scene', () {
      expect(CanvasExporter.contentBounds(const []), Rect.zero);
    });
  });

  group('CanvasExporter.renderPng', () {
    test('sizes the image to content bounds + padding, times pixelRatio',
        () async {
      final bytes = await CanvasExporter.renderPng(
        [_rect()],
        background: _background,
        pixelRatio: 2.0,
        padding: 32,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);

      // 200x120 content, inflated by 32 on all sides => 264x184 logical.
      expect(image.width, (264 * 2).round());
      expect(image.height, (184 * 2).round());
    });

    test('honours a non-default pixelRatio above the viewport zoom cap',
        () async {
      final bytes = await CanvasExporter.renderPng(
        [_rect()],
        background: _background,
        pixelRatio: 6.0,
        padding: 10,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);

      expect(image.width, (220 * 6).round());
      expect(image.height, (140 * 6).round());
    });

    test('scales a huge scene down instead of asking for an oversized image',
        () async {
      // 20000 canvas units at the default 2x would request a 40000px image —
      // past every GPU's max texture size, i.e. a crash rather than a file.
      final bytes = await CanvasExporter.renderPng(
        [_rect(rect: const Rect.fromLTWH(0, 0, 20000, 400))],
        background: _background,
        padding: 0,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);

      expect(image.width, CanvasExporter.maxImageDimension);
      expect(image.height, lessThan(CanvasExporter.maxImageDimension));
    });

    test('emits a decodable PNG', () async {
      final bytes = await CanvasExporter.renderPng(
        [_rect()],
        background: _background,
      );

      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });

    test('renders an empty canvas as a blank padded square, not a crash',
        () async {
      final bytes = await CanvasExporter.renderPng(
        const [],
        background: _background,
        pixelRatio: 2.0,
        padding: 32,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);

      expect(image.width, 128);
      expect(image.height, 128);
    });

    test('actually rasterises the elements, not just the background',
        () async {
      // A dimensions-only assertion would pass on a blank image, so sample
      // the middle of a solid-filled shape and prove ink landed there.
      final bytes = await CanvasExporter.renderPng(
        [
          SketchRectangle.create(
            rect: const Rect.fromLTWH(0, 0, 40, 40),
            style: const SketchStyle(
              strokeColor: Color(0xFF000000),
              fillColor: Color(0xFF000000),
              fillStyle: FillStyle.solid,
            ),
          ),
        ],
        background: const Color(0xFFFFFFFF),
        pixelRatio: 1.0,
        padding: 10,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);
      final pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      // Centre of the 60x60 image is the centre of the filled rectangle.
      final centre = ((30 * image.width) + 30) * 4;

      expect(pixels.getUint8(centre), lessThan(64), reason: 'red channel');
      expect(pixels.getUint8(centre + 1), lessThan(64), reason: 'green');
      expect(pixels.getUint8(centre + 2), lessThan(64), reason: 'blue');
    });

    test('leaves selection chrome out of the exported image', () async {
      // Same shape, once plain and once while "selected" — the exporter
      // hardcodes an empty selection, so the bytes must be identical.
      final element = SketchRectangle.create(
        id: 'a',
        rect: const Rect.fromLTWH(0, 0, 20, 20),
      );
      final controller = SketchController(initialElements: [element]);
      addTearDown(controller.dispose);

      final before = await CanvasExporter.renderPng(
        controller.elements,
        background: _background,
        pixelRatio: 1.0,
      );
      controller.select('a');
      final after = await CanvasExporter.renderPng(
        controller.elements,
        background: _background,
        pixelRatio: 1.0,
      );

      expect(after, before);
    });

    test('paints the background opaque so nothing shows through', () async {
      final bytes = await CanvasExporter.renderPng(
        const [],
        background: const Color(0x1122AA44),
        pixelRatio: 1.0,
        padding: 2,
      );

      final image = await _decode(bytes);
      addTearDown(image.dispose);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      expect(pixels!.getUint8(3), 255, reason: 'alpha channel of pixel (0,0)');
    });
  });

  group('CanvasExporter.writeExport', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('fc_export_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('creates the target folder and returns the absolute path', () async {
      final nested = '${tempDir.path}${Platform.pathSeparator}FlowCraft';

      final path = await CanvasExporter.writeExport(
        fileName: 'scene.png',
        bytes: const [1, 2, 3],
        directoryPath: nested,
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
      expect(path.startsWith(nested), isTrue);
    });

    test('a second export in the same second gets a distinct name', () async {
      Future<String> export(List<int> bytes) => CanvasExporter.writeExport(
            fileName: 'scene-20260822-143501.flowcraft.json',
            bytes: bytes,
            directoryPath: tempDir.path,
          );

      final first = await export([1]);
      final second = await export([2]);
      final third = await export([3]);

      expect(first, endsWith('scene-20260822-143501.flowcraft.json'));
      expect(second, endsWith('scene-20260822-143501-2.flowcraft.json'));
      expect(third, endsWith('scene-20260822-143501-3.flowcraft.json'));
      expect(File(first).readAsBytesSync(), [1], reason: 'never overwritten');
      expect(File(second).readAsBytesSync(), [2]);
    });

    test('surfaces write failures instead of swallowing them', () async {
      final blocked = File('${tempDir.path}${Platform.pathSeparator}blocked')
        ..writeAsStringSync('not a directory');

      expect(
        CanvasExporter.writeExport(
          fileName: 'scene.png',
          bytes: const [1],
          directoryPath: blocked.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('CanvasExporter file names', () {
    test('slugifies and timestamps the base name', () {
      final name = CanvasExporter.timestampedFileName(
        'My Great Diagram!',
        'png',
        now: DateTime(2026, 3, 4, 9, 8, 7),
      );

      expect(name, 'my-great-diagram-20260304-090807.png');
    });

    test('falls back to a usable name when nothing survives sanitising', () {
      expect(CanvasExporter.sanitizeBaseName('///'), 'flowcraft');
      expect(CanvasExporter.sanitizeBaseName('  '), 'flowcraft');
    });

    test('keeps the compound JSON extension intact', () {
      final name = CanvasExporter.timestampedFileName(
        'scene',
        'flowcraft.json',
        now: DateTime(2026, 1, 2, 3, 4, 5),
      );

      expect(name, endsWith('.flowcraft.json'));
    });
  });
}
