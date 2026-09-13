import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../ai/application/ai_providers.dart';
import '../../ai/data/ai_models.dart';
import '../../couple/application/couple_providers.dart';
import '../../spicy/application/spicy_providers.dart';
import '../data/creature_chat_models.dart';
import '../data/creature_persona.dart';
import '../data/location_service.dart';
import 'creature_controller.dart';

const _foggy =
    'Hmm, my brain\'s a little foggy right now — try me again in a bit 🌫️';
const _greeting = 'Hi you two 🤍 what\'s on your mind?';

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

      _replaceThinking(
        reply.text.trim().isEmpty ? _foggy : reply.text.trim(),
        movies: reply.movies,
        places: reply.places,
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
      {List<MovieCard> movies = const [], List<PlaceCard> places = const []}) {
    if (!mounted) return;
    final list = [...state];
    final i = list.lastIndexWhere((m) => m.thinking);
    if (i >= 0) {
      list[i] = CreatureChatMessage(
          fromCreature: true, text: text, movies: movies, places: places);
      state = list;
    }
  }
}

final creatureChatProvider = StateNotifierProvider.autoDispose
    .family<CreatureChatController, List<CreatureChatMessage>, String>(
  (ref, coupleId) => CreatureChatController(ref, coupleId),
);
