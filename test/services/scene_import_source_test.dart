import 'dart:io';

import 'package:flowcraft/flowcraft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('fc_import_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File write(String name, String contents, {DateTime? modified}) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync(contents);
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  test('lists only .json files, newest first', () async {
    write('old.json', '{}', modified: DateTime(2026, 1, 1));
    write('new.flowcraft.json', '{}', modified: DateTime(2026, 6, 1));
    // The export folder is shared with PNG exports, which are not importable.
    write('board.png', 'not json');

    final found = await SceneImportSource.list(directoryPath: tempDir.path);

    expect(found.map((s) => s.name), ['new.flowcraft.json', 'old.json']);
  });

  test('an absent folder is empty, not an error', () async {
    // Nothing has been exported yet — the dialog says so better than a
    // FileSystemException would.
    final found = await SceneImportSource.list(
      directoryPath: '${tempDir.path}${Platform.pathSeparator}nope',
    );

    expect(found, isEmpty);
  });

  test('reads a file back verbatim', () async {
    final file = write('scene.json', '{"version": 1, "elements": []}');

    expect(await SceneImportSource.read(file.path),
        '{"version": 1, "elements": []}');
  });

  test('expands a leading ~, which is how people write paths by hand', () {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];

    expect(SceneImportSource.expandHome('~/board.json'), '$home/board.json');
    expect(SceneImportSource.expandHome('/tmp/board.json'), '/tmp/board.json');
  }, skip: (Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE']) ==
          null
      ? 'no home directory in this environment'
      : null);

  test('surfaces the real reason a path cannot be read', () {
    expect(
      SceneImportSource.read('${tempDir.path}/missing.json'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('reports the size of what it found', () async {
    write('scene.json', 'x' * 2048);

    final found = await SceneImportSource.list(directoryPath: tempDir.path);

    expect(found.single.sizeBytes, 2048);
    expect(found.single.sizeLabel, '2.0 KB');
  });
}
