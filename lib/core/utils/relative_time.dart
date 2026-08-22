/// Formats timestamps the way a chat-history sidebar does: coarse and
/// scannable, never a precise date the eye has to parse.
class RelativeTime {
  RelativeTime._();

  /// Renders how long ago [time] was — `just now`, `12m ago`, `3h ago`,
  /// `5d ago`, `2w ago`, then an absolute `2026-03-14` once relative
  /// wording stops being useful.
  ///
  /// [now] is injectable so tests don't depend on the wall clock.
  static String format(DateTime time, {DateTime? now}) {
    final delta = (now ?? DateTime.now()).difference(time);

    // Clock skew or a file written by a machine running ahead — reading
    // "in 3 hours" in a history list is worse than reading "just now".
    if (delta.isNegative || delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    if (delta.inDays < 28) return '${delta.inDays ~/ 7}w ago';

    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }
}
