import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/services/export_file_sink.dart';

void main() {
  late Directory root;
  late String protectedDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('export_sink_');
    protectedDir = '${root.path}/.flowcraft';
    Directory('$protectedDir/projects').createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<String> write(String path, {bool overwrite = false}) =>
      ExportFileSink.writeTo(
        path,
        [1, 2, 3],
        overwrite: overwrite,
        protectedDirectoryPath: protectedDir,
      );

  Matcher refused(String part) => throwsA(
    isA<ExportPathException>().having(
      (e) => e.message,
      'message',
      contains(part),
    ),
  );

  test('writes bytes to an absolute path', () async {
    final path = await write('${root.path}/a.svg');
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });

  test('relative path refused', () {
    expect(write('a.svg'), refused('absolute'));
  });

  test('.. segments refused', () {
    expect(write('${root.path}/x/../a.svg'), refused('..'));
  });

  test('missing parent refused, not created', () async {
    await expectLater(write('${root.path}/nope/a.svg'), refused('parent'));
    expect(Directory('${root.path}/nope').existsSync(), isFalse);
  });

  test('parent is a file refused', () {
    File('${root.path}/f').writeAsStringSync('x');
    expect(write('${root.path}/f/a.svg'), refused('parent'));
  });

  test('symlink target refused', () {
    File('${root.path}/real').writeAsStringSync('x');
    Link('${root.path}/link.svg').createSync('${root.path}/real');
    expect(write('${root.path}/link.svg', overwrite: true), refused('symlink'));
  });

  test('directory target refused', () {
    Directory('${root.path}/d.svg').createSync();
    expect(write('${root.path}/d.svg', overwrite: true), refused('directory'));
  });

  test('projects dir refused', () {
    expect(write('$protectedDir/projects/a.json'), refused('data directory'));
  });

  test('symlinked parent into projects dir refused', () {
    Link('${root.path}/sneaky').createSync('$protectedDir/projects');
    expect(write('${root.path}/sneaky/a.json'), refused('data directory'));
  });

  test('existing without overwrite refused', () async {
    File('${root.path}/a.svg').writeAsStringSync('old');
    await expectLater(write('${root.path}/a.svg'), refused('overwrite'));
    expect(File('${root.path}/a.svg').readAsStringSync(), 'old');
  });

  test('overwrite works', () async {
    File('${root.path}/a.svg').writeAsStringSync('old');
    await write('${root.path}/a.svg', overwrite: true);
    expect(File('${root.path}/a.svg').readAsBytesSync(), [1, 2, 3]);
  });

  test('~ expands', () async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final dir = Directory(home).createTempSync('.export_sink_tilde_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final name = dir.path.split(Platform.pathSeparator).last;
    final path = await write('~/$name/a.svg');
    expect(path, '${dir.path}/a.svg');
    expect(File(path).existsSync(), isTrue);
  });

  test('no .tmp left behind', () async {
    await write('${root.path}/a.svg');
    File('${root.path}/b.svg').writeAsStringSync('x');
    await expectLater(write('${root.path}/b.svg'), refused('overwrite'));
    expect(root.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
  });
}
