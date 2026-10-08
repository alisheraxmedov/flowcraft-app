import 'package:flowcraft/flowcraft.dart';
import 'package:flowcraft/views/widgets/link_file_dialog.dart';
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
      overrides: [
        projectRepositoryProvider.overrideWithValue(repository),
        mcpServerPortProvider.overrideWithValue(0),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Warms the view model before the first frame so the popover never renders
  /// its (endlessly animating) loading spinner, then opens it from the button.
  Future<void> pumpPopover(WidgetTester tester) async {
    await container.read(projectsViewModelProvider.notifier).ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Align(child: ProjectsButton())),
        ),
      ),
    );
    await tester.tap(find.byType(ProjectsButton));
    await tester.pumpAndSettle();
  }

  ProjectsState state() => container.read(projectsViewModelProvider);

  Future<void> openRowMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
  }

  testWidgets('projects popover opens below the Projects button', (
    tester,
  ) async {
    await pumpPopover(tester);

    final button = tester.getRect(find.byType(ProjectsButton));
    final popover = tester.getRect(
      find
          .ancestor(
            of: find.byType(ProjectsPopover),
            matching: find.byType(GlassIsland),
          )
          .first,
    );
    expect(popover.left, button.left);
    expect(popover.top, button.bottom + 6);
  });

  testWidgets('opens from the button, lists projects, marks the active one', (
    tester,
  ) async {
    final project = await repository.create('Architecture');
    await repository.save(
      id: project.id,
      elements: [SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 4, 4))],
    );
    await container.read(projectsViewModelProvider.notifier).ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Align(child: ProjectsButton())),
        ),
      ),
    );
    expect(find.byType(ProjectsPopover), findsNothing);
    await tester.tap(find.byType(ProjectsButton));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Architecture'), findsOneWidget);
    expect(find.textContaining('1 element ·'), findsOneWidget);
    expect(
      tester.widget<ProjectTile>(find.byType(ProjectTile)).isActive,
      isTrue,
    );
  });

  testWidgets('creates a project from the New project button', (tester) async {
    await pumpPopover(tester);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Flow diagram');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(state().active?.name, 'Flow diagram');
    expect(find.byType(ProjectsPopover), findsNothing);
  });

  testWidgets('closes the popover when a project is opened', (tester) async {
    final other = await repository.create('Other');
    await repository.save(
      id: other.id,
      elements: [SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 4, 4))],
    );
    await repository.create('Newer');
    await pumpPopover(tester);

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsPopover), findsNothing);
    expect(state().activeId, other.id);
    // loadScene, not replaceAll: no undo entry pulling the old scene back.
    final canvas = container.read(sketchControllerProvider);
    expect(canvas.elements, hasLength(1));
    expect(canvas.canUndo, isFalse);
  });

  testWidgets('renames through the row menu', (tester) async {
    await repository.create('Before');
    await pumpPopover(tester);

    await openRowMenu(tester);
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
    await pumpPopover(tester);

    await openRowMenu(tester);
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
    await pumpPopover(tester);

    expect(find.text('/tmp/board.flowcraft'), findsOneWidget);

    await openRowMenu(tester);
    await tester.tap(find.text('Unlink file'));
    await tester.pumpAndSettle();

    expect(find.text('/tmp/board.flowcraft'), findsNothing);
  });

  testWidgets('delete needs an explicit confirm', (tester) async {
    await repository.create('Doomed');
    await pumpPopover(tester);

    await openRowMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Doomed"?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);

    await openRowMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Doomed'), findsNothing);
  });

  testWidgets('shows a corrupt project as a disabled row', (tester) async {
    await repository.create('Healthy');
    repository.brokenIds.add('proj_bad');

    await pumpPopover(tester);

    expect(find.text("Can't be read"), findsOneWidget);
    final broken = tester
        .widgetList<ProjectTile>(find.byType(ProjectTile))
        .firstWhere((tile) => tile.project.isBroken);
    expect(broken.isActive, isFalse);
    await tester.tap(find.text("Can't be read"));
    expect(state().active?.name, 'Healthy');
    expect(find.byType(ProjectsPopover), findsOneWidget);
  });

  testWidgets('surfaces a failure in a banner instead of silently', (
    tester,
  ) async {
    await pumpPopover(tester);

    await container
        .read(projectsViewModelProvider.notifier)
        .openProject('proj_missing');
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open project'), findsOneWidget);
  });
}
