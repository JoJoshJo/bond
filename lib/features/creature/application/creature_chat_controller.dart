import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/utils/dev_error.dart';
import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_models.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/data/calendar_models.dart';
import '../../premium/application/entitlement_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../../spicy/application/spicy_providers.dart';
import '../data/creature_chat_models.dart';
import '../data/creature_persona.dart';
import '../data/location_service.dart';
import 'creature_controller.dart';

const _foggy =
    'Hmm, my brain\'s a little foggy right now — try me again in a bit 🌫️';
const _greeting = 'Hi you two 🤍 what\'s on your mind?';
const _calendarUpsell =
    'Ooh, I\'d love to handle your calendar for you two — that\'s a Usora+ thing 🤍';

/// Ephemeral creature conversation. Tap-only (never speaks unsolicited); replies
/// via the ai-router `creature` job, with the in-character foggy-brain fallback.
class CreatureChatController extends StateNotifier<List<CreatureChatMessage>> {
  CreatureChatController(this._ref, this._coupleId)
      : super(const [
          CreatureChatMessage(fromCreature: true, text: _greeting),
        ]);

  final Ref _ref;
  final String _coupleId;
  bool _sending = false;

  // Session-only location cache (memory; cleared when the chat closes). Never
  // stored server-side; only sent to our function per-request.
  double? _lat;
  double? _lng;

  bool get sending => _sending;

  Future<void> send(String input) async {
    final text = input.trim();
    if (text.isEmpty || _sending) return;
    _sending = true;

    state = [
      ...state,
      CreatureChatMessage(fromCreature: false, text: text),
      const CreatureChatMessage(fromCreature: true, text: '', thinking: true),
    ];

    try {
      var reply = await _ask(text);

      // Location handshake: creature wants a place search but we have no coords.
      if (reply.needsLocation && _lat == null) {
        final loc = await const LocationService().current();
        if (loc != null) {
          _lat = loc.lat;
          _lng = loc.lng;
          reply = await _ask(text); // resend, now with coordinates
        } else {
          _replaceThinking(
              'I\'d love to find spots near you two — turn on location for Usora and ask me again 🤍');
          return;
        }
      }

      var replyText = reply.text.trim().isEmpty ? _foggy : reply.text.trim();
      var proposal = reply.calendarAction;
      var showUpgrade = reply.premiumRequired;
      // App-side Usora+ gate (the router gates independently): a free couple
      // never even sees a Yes button for a calendar change.
      if (proposal != null && !_ref.read(isPremiumProvider)) {
        proposal = null;
        showUpgrade = true;
        replyText = _calendarUpsell;
      }

      _replaceThinking(
        replyText,
        movies: reply.movies,
        places: reply.places,
        proposal: proposal,
        showUpgrade: showUpgrade,
      );
    } catch (_) {
      _replaceThinking(_foggy);
    } finally {
      _sending = false;
    }
  }

  Future<AiResponse> _ask(String text) {
    final spicy = _ref.read(spicyActiveProvider);
    return _ref
        .read(aiRepositoryProvider)
        .getAI('creature', CreaturePersona.prompt(text, spicy: spicy),
            context: _context())
        .timeout(const Duration(seconds: 30));
  }

  /// Minimal context: couple name + mood; plus lat/lng ONLY when we already have
  /// it (opt-in, per-request). No messages/personal data.
  Map<String, dynamic> _context() {
    final membership = _ref.read(myMembershipProvider).asData?.value;
    final mood = _ref.read(creatureStateProvider(_coupleId)).asData?.value.mood;
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final ctx = <String, dynamic>{
      'coupleName': membership?.coupleName ?? 'you two',
      // For resolving relative dates ("Friday", "next week") in calendar tools.
      'today': today,
    };
    // Relationship milestones — lets Usora reference how long they've been
    // together naturally (only when the couple has set a start date).
    final start = membership?.relationshipStartDate;
    if (start != null) {
      ctx['relationshipStartDate'] = '${start.year.toString().padLeft(4, '0')}-'
          '${start.month.toString().padLeft(2, '0')}-'
          '${start.day.toString().padLeft(2, '0')}';
      final days = now.difference(start).inDays;
      if (days >= 0) ctx['daysTogether'] = days;
    }
    if (mood != null) ctx['mood'] = mood.name;
    if (_ref.read(spicyActiveProvider)) ctx['spicy'] = true;
    if (_lat != null && _lng != null) {
      ctx['lat'] = _lat;
      ctx['lng'] = _lng;
    }
    return ctx;
  }

  void _replaceThinking(String text,
      {List<MovieCard> movies = const [],
      List<PlaceCard> places = const [],
      CalendarProposal? proposal,
      bool showUpgrade = false}) {
    if (!mounted) return;
    final list = [...state];
    final i = list.lastIndexWhere((m) => m.thinking);
    if (i >= 0) {
      list[i] = CreatureChatMessage(
          fromCreature: true,
          text: text,
          movies: movies,
          places: places,
          proposal: proposal,
          showUpgrade: showUpgrade);
      state = list;
    }
  }

  // ---------------------------------------------------------------------------
  // Calendar proposals. Nothing is written until the couple taps Yes; then the
  // write goes through the SAME CalendarController the manual editor uses
  // (same RLS, same refresh). The current event is re-read from the calendar —
  // the router's copy is only used to know WHAT changed.
  // ---------------------------------------------------------------------------

  /// "No": dismiss, never write.
  void declineProposal(int index) {
    final m = _proposalAt(index);
    if (m == null) return;
    _setStatus(index, ProposalStatus.declined);
    _say('No problem — I\'ll leave your calendar as it is 🤍');
  }

  /// "Yes": apply the change through the normal calendar write path.
  Future<void> confirmProposal(int index) async {
    final m = _proposalAt(index);
    final p = m?.proposal;
    if (m == null || p == null) return;
    // Re-check at the moment of writing (premium may have lapsed).
    if (!_ref.read(isPremiumProvider)) {
      _setStatus(index, ProposalStatus.declined);
      _say(_calendarUpsell, showUpgrade: true);
      return;
    }
    _setStatus(index, ProposalStatus.applying);
    try {
      final calendar =
          _ref.read(calendarControllerProvider(_coupleId).notifier);
      switch (p.op) {
        case CalendarOp.add:
          final a = p.after!;
          await calendar.add(
            label: a.title,
            date: a.date,
            time: _tod(a),
            note: a.note,
            type: a.type,
            recurringYearly: a.recurring,
          );
          _setStatus(index, ProposalStatus.applied);
          _say('Done — "${a.title}" is on your calendar for ${_when(a)} 🤍');
        case CalendarOp.update:
          final current = await _currentEvent(p.eventId!);
          if (current == null) return _gone(index);
          final a = p.after!, b = p.before!;
          // Apply only the fields Usora proposed changing onto the LIVE event.
          await calendar.update(
            id: current.id,
            label: a.title != b.title ? a.title : current.label,
            date: _sameDay(a.date, b.date) ? current.date : a.date,
            time: (a.hour != b.hour || a.minute != b.minute)
                ? _tod(a)
                : current.time,
            note: a.note != b.note ? a.note : current.note,
            type: current.type,
            recurringYearly: current.recurringYearly,
          );
          _setStatus(index, ProposalStatus.applied);
          _say('Done — "${a.title}" is now ${_when(a)} 🤍');
        case CalendarOp.delete:
          final current = await _currentEvent(p.eventId!);
          if (current == null) return _gone(index);
          await calendar.remove(current.id);
          _setStatus(index, ProposalStatus.applied);
          _say('Done — I took "${current.label}" off your calendar 🤍');
      }
    } catch (e, st) {
      debugPrint('calendar ${p.op.name} via chat failed: $e\n$st');
      _setStatus(index, ProposalStatus.failed,
          error: kShowDevTools ? devErrorText(e) : null);
      _say('Hmm, that didn\'t save — nothing changed. Try again in a moment? 🌫️');
    }
  }

  CreatureChatMessage? _proposalAt(int index) {
    if (index < 0 || index >= state.length) return null;
    final m = state[index];
    if (m.proposal == null || m.proposalStatus != ProposalStatus.pending) {
      return null;
    }
    return m;
  }

  void _gone(int index) {
    _setStatus(index, ProposalStatus.failed);
    _say('Hmm, I can\'t find that one on your calendar anymore — nothing changed 🤍');
  }

  /// The live event (from the couple's calendar, RLS-scoped) or null.
  Future<CoupleEvent?> _currentEvent(String id) async {
    final provider = calendarControllerProvider(_coupleId);
    var s = _ref.read(provider);
    for (var i = 0; s.loading && i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      s = _ref.read(provider);
    }
    for (final e in s.events) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _setStatus(int index, ProposalStatus status, {String? error}) {
    if (!mounted || index >= state.length) return;
    final list = [...state];
    list[index] =
        list[index].copyWith(proposalStatus: status, proposalError: error);
    state = list;
  }

  void _say(String text, {bool showUpgrade = false}) {
    if (!mounted) return;
    state = [
      ...state,
      CreatureChatMessage(
          fromCreature: true, text: text, showUpgrade: showUpgrade),
    ];
  }

  static TimeOfDay? _tod(ProposedEvent e) =>
      e.hasTime ? TimeOfDay(hour: e.hour!, minute: e.minute!) : null;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _when(ProposedEvent e) => describeProposedWhen(e);
}

final creatureChatProvider = StateNotifierProvider.autoDispose
    .family<CreatureChatController, List<CreatureChatMessage>, String>(
  (ref, coupleId) => CreatureChatController(ref, coupleId),
);

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Fri, Sep 25 at 8:00 PM" / "Mon, Oct 12" — plain-language event timing.
String describeProposedWhen(ProposedEvent e) {
  final d = e.date;
  final day = '${_wd[d.weekday - 1]}, ${_mo[d.month - 1]} ${d.day}'
      '${d.year != DateTime.now().year ? ', ${d.year}' : ''}';
  if (!e.hasTime) return day;
  final h = e.hour!, m = e.minute!;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$day at $h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}
