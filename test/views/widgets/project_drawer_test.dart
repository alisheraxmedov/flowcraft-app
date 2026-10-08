import 'package:flowcraft/views/widgets/link_file_dialog.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeProjectRepository();
    container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  /// Warms the view model before the first frame so the drawer never renders
  /// its (endlessly animating) loading spinner — `pumpAndSettle` would
  /// otherwise never settle.
  Future<void> pumpDrawer(WidgetTester tester, {VoidCallback? onOpened}) async {
    await container.read(projectsViewModelProvider.notifier).ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: ProjectDrawer(onProjectOpened: onOpened)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProjectsState state() => container.read(projectsViewModelProvider);

  testWidgets('lists projects with their size and marks the active one', (
    tester,
  ) async {
    final project = await repository.create('Architecture');
    await repository.save(
      id: project.id,
      elements: [SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 4, 4))],
    );

    await pumpDrawer(tester);

    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('Architecture'), findsOneWidget);
    expect(find.textContaining('1 element ·'), findsOneWidget);
    expect(
      tester.widget<ProjectTile>(find.byType(ProjectTile)).isActive,
      isTrue,
    );
  });

  testWidgets('creates a project from the New project button', (tester) async {
    await pumpDrawer(tester);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Flow diagram');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Flow diagram'), findsOneWidget);
    expect(state().active?.name, 'Flow diagram');
  });

  testWidgets('notifies the host after opening a project', (tester) async {
    final other = await repository.create('Other');
    var opened = 0;
    await pumpDrawer(tester, onOpened: () => opened++);

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(state().activeId, other.id);
  });

  testWidgets('renames through the row menu', (tester) async {
    await repository.create('Before');
    await pumpDrawer(tester);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'After');
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();

    expect(find.text('After'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
  });

  testWidgets('Link to file… opens dialog and links', (tester) async {
    final project = await repository.create('Doc');
    await pumpDrawer(tester);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to file…'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '/tmp/board.txt');
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('.flowcraft or .json'), findsWidgets);

    await tester.enterText(find.byType(TextField), '/tmp/board.flowcraft');
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();

    expect(find.byType(LinkFileDialog), findsNothing);
    expect(
      state().projects.firstWhere((p) => p.id == project.id).linkedPath,
      '/tmp/board.flowcraft',
    );
  });

  testWidgets('linked path shown, Unlink file clears it', (tester) async {
    final project = await repository.create('Doc');
    await repository.link(project.id, '/tmp/board.flowcraft');
    await pumpDrawer(tester);

    expect(find.text('/tmp/board.flowcraft'), findsOneWidget);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink file'));
    await tester.pumpAndSettle();

    expect(find.text('/tmp/board.flowcraft'), findsNothing);
  });

  testWidgets('delete needs an explicit confirm', (tester) async {
    await repository.create('Doomed');
    await pumpDrawer(tester);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Doomed"?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Doomed'), findsNothing);
  });

  testWidgets('shows a corrupt project as an unopenable row', (tester) async {
    await repository.create('Healthy');
    repository.brokenIds.add('proj_bad');

    await pumpDrawer(tester);

    expect(find.text("Can't be read"), findsOneWidget);
    final broken = tester
        .widgetList<ProjectTile>(find.byType(ProjectTile))
        .firstWhere((tile) => tile.project.isBroken);
    expect(broken.isActive, isFalse);
    expect(state().active?.name, 'Healthy');
  });

  testWidgets('closes its own drawer when hosted as Scaffold.drawer', (
    tester,
  ) async {
    final other = await repository.create('Other');
    await container.read(projectsViewModelProvider.notifier).ready;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const ProjectDrawer(),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDrawer), findsNothing);
    expect(state().activeId, other.id);
  });

  testWidgets('surfaces a failure in a banner instead of silently', (
    tester,
  ) async {
    await pumpDrawer(tester);

    await container
        .read(projectsViewModelProvider.notifier)
        .openProject('proj_missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open project'), findsOneWidget);
  });
}
