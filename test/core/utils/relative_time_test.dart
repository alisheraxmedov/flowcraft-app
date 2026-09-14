import 'package:flowcraft/flowcraft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12);

  String ago(Duration delta) =>
      RelativeTime.format(now.subtract(delta), now: now);

  test('collapses the last minute to "just now"', () {
    expect(ago(Duration.zero), 'just now');
    expect(ago(const Duration(seconds: 59)), 'just now');
  });

  test('counts minutes, then hours, then days, then weeks', () {
    expect(ago(const Duration(minutes: 1)), '1m ago');
    expect(ago(const Duration(minutes: 59)), '59m ago');
    expect(ago(const Duration(hours: 1)), '1h ago');
    expect(ago(const Duration(hours: 23)), '23h ago');
    expect(ago(const Duration(days: 1)), '1d ago');
    expect(ago(const Duration(days: 6)), '6d ago');
    expect(ago(const Duration(days: 14)), '2w ago');
  });

  test(
    'falls back to an absolute date once relative wording stops helping',
    () {
      expect(ago(const Duration(days: 90)), '2026-03-17');
    },
  );

  test('reads a future timestamp as "just now" rather than "in 3 hours"', () {
    expect(
      RelativeTime.format(now.add(const Duration(hours: 3)), now: now),
      'just now',
    );
  });
}
