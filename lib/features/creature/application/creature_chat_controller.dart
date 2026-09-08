import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../ai/application/ai_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../data/creature_chat_models.dart';
import '../data/creature_persona.dart';
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
      final reply = await _ref
          .read(aiRepositoryProvider)
          .getAI('creature', CreaturePersona.prompt(text), context: _context())
          .timeout(const Duration(seconds: 25));
      _replaceThinking(reply.text.trim().isEmpty ? _foggy : reply.text.trim());
    } catch (_) {
      // Router already retried transient failures; stay in character.
      _replaceThinking(_foggy);
    } finally {
      _sending = false;
    }
  }

  /// Minimal context only — couple name + mood label. No messages/personal data.
  Map<String, dynamic> _context() {
    final membership = _ref.read(myMembershipProvider).asData?.value;
    final mood = _ref.read(creatureStateProvider(_coupleId)).asData?.value.mood;
    final ctx = <String, dynamic>{'coupleName': membership?.coupleName ?? 'you two'};
    if (mood != null) ctx['mood'] = mood.name;
    return ctx;
  }

  void _replaceThinking(String text) {
    if (!mounted) return;
    final list = [...state];
    final i = list.lastIndexWhere((m) => m.thinking);
    if (i >= 0) {
      list[i] = CreatureChatMessage(fromCreature: true, text: text);
      state = list;
    }
  }
}

final creatureChatProvider = StateNotifierProvider.autoDispose
    .family<CreatureChatController, List<CreatureChatMessage>, String>(
  (ref, coupleId) => CreatureChatController(ref, coupleId),
);
