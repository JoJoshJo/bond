import 'package:flutter/foundation.dart';

import '../data/memory_models.dart';

/// "On this day": a memory whose anniversary falls within ±[windowDays] of
/// today, from a previous year. Prefers the closest day, then the most recent
/// year. Shared by the home contextual slot and the Memories screen band.
ResurfacedMemory? resurfaceMemory(Iterable<Memory> memories, DateTime now,
    {int windowDays = 3}) {
  // UTC date-only math so DST shifts can't produce off-by-one day counts.
  final today = DateTime.utc(now.year, now.month, now.day);
  ResurfacedMemory? best;
  for (final m in memories) {
    // Check the anniversary in last/this/next year to handle Dec↔Jan wrap.
    for (final year in [today.year - 1, today.year, today.year + 1]) {
      final anniversary = DateTime.utc(year, m.takenAt.month, m.takenAt.day);
      final dayOffset = anniversary.difference(today).inDays.abs();
      final years = year - m.takenAt.year;
      if (dayOffset > windowDays || years < 1) continue;
      final candidate =
          ResurfacedMemory(memory: m, years: years, dayOffset: dayOffset);
      if (best == null || candidate.isBetterThan(best)) best = candidate;
    }
  }
  return best;
}

@immutable
class ResurfacedMemory {
  const ResurfacedMemory(
      {required this.memory, required this.years, required this.dayOffset});

  final Memory memory;
  final int years;
  final int dayOffset;

  bool isBetterThan(ResurfacedMemory other) {
    if (dayOffset != other.dayOffset) return dayOffset < other.dayOffset;
    if (years != other.years) return years < other.years;
    return memory.takenAt.isAfter(other.memory.takenAt);
  }

  /// Google-Photos-style eyebrow.
  String get eyebrow {
    final when = dayOffset == 0 ? 'today' : 'this week';
    return years == 1 ? 'A year ago $when' : '$years years ago $when';
  }

  /// No title field exists on memories — use the caption, else the date.
  String get title {
    final caption = memory.caption?.trim();
    if (caption != null && caption.isNotEmpty) return caption;
    return memoryLongDate(memory.takenAt);
  }
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "September 21, 2026".
String memoryLongDate(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
