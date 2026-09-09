import 'package:flutter/material.dart';

/// A shared couple event, stored in `important_dates`. Couple-owned; both
/// partners see the same set.
@immutable
class CoupleEvent {
  const CoupleEvent({
    required this.id,
    required this.label,
    required this.date,
    this.time,
    this.note,
    this.type = 'custom',
    this.recurringYearly = false,
    this.reminderMinutes,
  });

  final String id;
  final String label;
  final DateTime date; // date-only (local midnight)
  final TimeOfDay? time; // null = all-day
  final String? note;
  final String type; // see [EventType]
  final bool recurringYearly;
  final int? reminderMinutes; // placeholder for the reminders follow-up

  factory CoupleEvent.fromRow(Map<String, dynamic> row) {
    final d = DateTime.parse(row['date'] as String);
    return CoupleEvent(
      id: row['id'] as String,
      label: (row['label'] as String?) ?? '',
      date: DateTime(d.year, d.month, d.day),
      time: _parseTime(row['event_time'] as String?),
      note: row['note'] as String?,
      type: (row['type'] as String?) ?? 'custom',
      recurringYearly: (row['recurring_yearly'] as bool?) ?? false,
      reminderMinutes: (row['reminder_minutes'] as num?)?.toInt(),
    );
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// This event's occurrence in a given year — for expanding recurring-yearly
  /// events (e.g. anniversaries) onto the calendar and upcoming list.
  DateTime occurrenceInYear(int year) => DateTime(year, date.month, date.day);

  /// The next upcoming occurrence on/after [from]. For one-off events that's the
  /// date itself; for recurring, the next yearly hit.
  DateTime nextOccurrence(DateTime from) {
    final f = DateTime(from.year, from.month, from.day);
    if (!recurringYearly) return date;
    var occ = occurrenceInYear(f.year);
    if (occ.isBefore(f)) occ = occurrenceInYear(f.year + 1);
    return occ;
  }
}

/// The event types the editor offers. `key` is stored in `important_dates.type`
/// (free text); label + icon are presentation only.
enum EventType {
  anniversary('anniversary', 'Anniversary', Icons.favorite_rounded),
  dateNight('date_night', 'Date night', Icons.local_bar_rounded),
  milestone('milestone', 'Milestone', Icons.flag_rounded),
  reminder('reminder', 'Reminder', Icons.notifications_rounded),
  custom('custom', 'Custom', Icons.event_rounded);

  const EventType(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;

  static EventType fromKey(String key) =>
      EventType.values.firstWhere((t) => t.key == key, orElse: () => custom);
}
