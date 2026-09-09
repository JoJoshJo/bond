import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calendar_models.dart';

/// Data access for the shared couple calendar (`important_dates`). Member-scoped
/// CRUD under RLS — plain inserts/updates/deletes, no RPCs. Realtime mirrors the
/// memory vault: postgres_changes filtered by couple_id.
class CalendarRepository {
  CalendarRepository(this._client);

  final SupabaseClient _client;

  Future<List<CoupleEvent>> fetch(String coupleId) async {
    final rows = await _client
        .from('important_dates')
        .select(
            'id, label, date, event_time, note, type, recurring_yearly, reminder_minutes')
        .eq('couple_id', coupleId)
        .order('date', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => CoupleEvent.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String coupleId,
    required String label,
    required DateTime date,
    TimeOfDay? time,
    String? note,
    required String type,
    required bool recurringYearly,
  }) async {
    await _client.from('important_dates').insert({
      'couple_id': coupleId,
      'label': label.trim(),
      'date': _ymd(date),
      'event_time': _timeStr(time),
      'note': _clean(note),
      'type': type,
      'recurring_yearly': recurringYearly,
    });
  }

  Future<void> update({
    required String id,
    required String label,
    required DateTime date,
    TimeOfDay? time,
    String? note,
    required String type,
    required bool recurringYearly,
  }) async {
    await _client.from('important_dates').update({
      'label': label.trim(),
      'date': _ymd(date),
      'event_time': _timeStr(time),
      'note': _clean(note),
      'type': type,
      'recurring_yearly': recurringYearly,
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('important_dates').delete().eq('id', id);
  }

  RealtimeChannel channel(String coupleId, {required void Function() onChange}) {
    return _client.channel('calendar_$coupleId').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'important_dates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (_) => onChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _timeStr(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String? _clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;
}
