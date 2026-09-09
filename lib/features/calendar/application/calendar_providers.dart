import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../data/calendar_models.dart';
import '../data/calendar_repository.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(supabaseClientProvider)),
);

class CalendarState {
  const CalendarState({this.loading = true, this.events = const []});

  final bool loading;
  final List<CoupleEvent> events;

  CalendarState copyWith({bool? loading, List<CoupleEvent>? events}) =>
      CalendarState(
        loading: loading ?? this.loading,
        events: events ?? this.events,
      );

  /// Events occurring on [day] (expands recurring-yearly to any year).
  List<CoupleEvent> eventsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return events.where((e) {
      if (e.recurringYearly) {
        return e.date.month == d.month && e.date.day == d.day;
      }
      return e.date.year == d.year &&
          e.date.month == d.month &&
          e.date.day == d.day;
    }).toList();
  }

  /// Upcoming occurrences on/after today, soonest first (recurring expanded to
  /// their next hit). Limited to [limit].
  List<({CoupleEvent event, DateTime when})> upcoming({int limit = 30}) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final list = events
        .map((e) => (event: e, when: e.nextOccurrence(t)))
        .where((x) => !x.when.isBefore(t))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return list.take(limit).toList();
  }
}

/// Loads and mutates the shared calendar for a couple; realtime-refreshed.
class CalendarController extends StateNotifier<CalendarState> {
  CalendarController(this._repo, this._coupleId)
      : super(const CalendarState()) {
    _init();
  }

  final CalendarRepository _repo;
  final String _coupleId;
  RealtimeChannel? _channel;

  Future<void> _init() async {
    await _refresh();
    _channel = _repo.channel(_coupleId, onChange: _refresh)..subscribe();
  }

  Future<void> _refresh() async {
    final events = await _repo.fetch(_coupleId);
    if (!mounted) return;
    state = state.copyWith(loading: false, events: events);
  }

  Future<void> add({
    required String label,
    required DateTime date,
    TimeOfDay? time,
    String? note,
    required String type,
    required bool recurringYearly,
  }) async {
    await _repo.add(
      coupleId: _coupleId,
      label: label,
      date: date,
      time: time,
      note: note,
      type: type,
      recurringYearly: recurringYearly,
    );
    await _refresh();
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
    await _repo.update(
      id: id,
      label: label,
      date: date,
      time: time,
      note: note,
      type: type,
      recurringYearly: recurringYearly,
    );
    await _refresh();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await _refresh();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

final calendarControllerProvider = StateNotifierProvider.autoDispose
    .family<CalendarController, CalendarState, String>((ref, coupleId) {
  return CalendarController(ref.watch(calendarRepositoryProvider), coupleId);
});
