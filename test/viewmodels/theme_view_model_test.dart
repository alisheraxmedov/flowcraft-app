import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  test('starts in light mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeViewModelProvider), isFalse);
  });

  test('toggle switches to dark mode and back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(themeViewModelProvider.notifier);

    notifier.toggle();
    expect(container.read(themeViewModelProvider), isTrue);

    notifier.toggle();
    expect(container.read(themeViewModelProvider), isFalse);
  });

  test('toggling notifies listeners', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final seen = <bool>[];
    container.listen<bool>(
      themeViewModelProvider,
      (previous, next) => seen.add(next),
      fireImmediately: true,
    );

    container.read(themeViewModelProvider.notifier).toggle();

    expect(seen, [false, true]);
  });
}
