import 'dart:math';

int _sequence = 0;
final Random _random = Random();

/// Returns a new id built from the current time, a per-session counter, and a
/// random suffix.
///
/// The counter keeps ids unique when several are created within one clock
/// tick (common on Windows, where the clock is coarse), and the random suffix
/// keeps ids from different devices apart when backups are merged.
String uniqueId([String prefix = '']) {
  _sequence = (_sequence + 1) % 1000000;
  final String id = '${DateTime.now().microsecondsSinceEpoch}_'
      '${_sequence.toString().padLeft(6, '0')}_'
      '${_random.nextInt(1 << 30).toRadixString(36)}';
  return prefix.isEmpty ? id : '${prefix}_$id';
}
