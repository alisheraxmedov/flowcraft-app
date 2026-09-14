import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_project_repository.dart';

/// Repository whose `create` refuses, leaving the view model with no active
/// project — the only state in which the title field renders nothing.
class _CreateFailsRepository extends FakeProjectRepository {
  @override
  Future<FlowProject> create(String name) async =>
      throw StateError('storage unavailable');
}

void main() {
  Future<ProviderContainer> pumpTitle(
    WidgetTester tester,
    FakeProjectRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(projectsViewModelProvider.notifier).ready;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ProjectTitleField())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the open project name', (tester) async {
    final repository = FakeProjectRepository();
    await repository.create('Alpha');

    await pumpTitle(tester, repository);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('clicking swaps in a pre-selected text field', (tester) async {
    final repository = FakeProjectRepository();
    await repository.create('Alpha');
    await pumpTitle(tester, repository);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Alpha');
    expect(field.controller!.selection.textInside('Alpha'), 'Alpha');
  });

  testWidgets('submitting renames the project', (tester) async {
    final repository = FakeProjectRepository();
    await repository.create('Alpha');
    final container = await pumpTitle(tester, repository);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(container.read(projectsViewModelProvider).active?.name, 'Beta');
    expect(find.text('Beta'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('escape abandons the edit', (tester) async {
    final repository = FakeProjectRepository();
    await repository.create('Alpha');
    final container = await pumpTitle(tester, repository);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Discarded');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(projectsViewModelProvider).active?.name, 'Alpha');
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets(
    'commits to the project the edit began on, not the one now open',
    (tester) async {
      // Renaming Alpha and then clicking a sidebar row both opens Beta and
      // blurs this field — the typed name must still land on Alpha.
      final repository = FakeProjectRepository();
      final alpha = await repository.create('Alpha');
      final beta = await repository.create('Beta');
      final container = await pumpTitle(tester, repository);
      await container
          .read(projectsViewModelProvider.notifier)
          .openProject(alpha.id);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed');

      await container
          .read(projectsViewModelProvider.notifier)
          .openProject(beta.id);
      await tester.pumpAndSettle();
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final projects = await repository.list();
      expect(projects.firstWhere((p) => p.id == alpha.id).name, 'Renamed');
      expect(projects.firstWhere((p) => p.id == beta.id).name, 'Beta');
    },
  );

  testWidgets('renders nothing when no project is open', (tester) async {
    await pumpTitle(tester, _CreateFailsRepository());

    expect(find.byType(TextField), findsNothing);
    expect(
      tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ProjectTitleField),
          matching: find.byType(SizedBox),
        ),
      ),
      isA<SizedBox>(),
    );
  });
}
