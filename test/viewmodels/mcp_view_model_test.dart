import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  test('starts enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mcpViewModelProvider), isTrue);
  });

  test('toggle switches between enabled and disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mcpViewModelProvider.notifier);

    notifier.toggle();
    expect(container.read(mcpViewModelProvider), isFalse);

    notifier.toggle();
    expect(container.read(mcpViewModelProvider), isTrue);
  });

  test('toggling notifies listeners', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final seen = <bool>[];
    container.listen<bool>(
      mcpViewModelProvider,
      (previous, next) => seen.add(next),
      fireImmediately: true,
    );

    container.read(mcpViewModelProvider.notifier).toggle();

    expect(seen, [true, false]);
  });
}
