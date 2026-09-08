import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../data/prompt_bank.dart';
import '../data/prompt_models.dart';
import '../data/prompt_repository.dart';

final promptRepositoryProvider = Provider<PromptRepository>(
  (ref) => PromptRepository(ref.watch(supabaseClientProvider)),
);

/// Immutable daily-prompt state.
class PromptState {
  const PromptState({
    this.phase = PromptPhase.loading,
    this.prompt,
    this.myResponse,
    this.partnerResponse,
    this.submitting = false,
    this.requesting = false,
  });

  final PromptPhase phase;
  final DailyPrompt? prompt;
  final PromptResponse? myResponse;
  final PromptResponse? partnerResponse;
  final bool submitting;
  final bool requesting;

  PromptState copyWith({
    PromptPhase? phase,
    DailyPrompt? prompt,
    Object? myResponse = _s,
    Object? partnerResponse = _s,
    bool? submitting,
    bool? requesting,
  }) {
    return PromptState(
      phase: phase ?? this.phase,
      prompt: prompt ?? this.prompt,
      myResponse:
          myResponse == _s ? this.myResponse : myResponse as PromptResponse?,
      partnerResponse: partnerResponse == _s
          ? this.partnerResponse
          : partnerResponse as PromptResponse?,
      submitting: submitting ?? this.submitting,
      requesting: requesting ?? this.requesting,
    );
  }

  static const _s = Object();
}

class PromptController extends StateNotifier<PromptState> {
  PromptController(this._repo, this._coupleId) : super(const PromptState()) {
    _init();
  }

  final PromptRepository _repo;
  final String _coupleId;
  RealtimeChannel? _channel;

  String get _me => _repo.currentUserId ?? '';

  Future<void> _init() async {
    final recent = await _repo.recentContents(_coupleId);
    final pick = PromptBank.pick(recent);
    final prompt = await _repo.getOrCreateDaily(pick.content, pick.category);
    if (!mounted) return;
    state = state.copyWith(prompt: prompt);
    await _refreshResponses();
    _openChannel(prompt.id);
  }

  void _openChannel(String promptId) {
    _channel?.let((c) => _repo.removeChannel(c));
    _channel = _repo.channel(
      promptId,
      onResponseChange: _refreshResponses,
      onReactionChange: _refreshResponses,
    )..subscribe();
  }

  Future<void> _refreshResponses() async {
    final prompt = state.prompt;
    if (prompt == null) return;
    final responses = await _repo.fetchResponses(prompt.id);
    if (!mounted) return;

    PromptResponse? mine;
    PromptResponse? partner;
    for (final r in responses) {
      if (r.userId == _me) {
        mine = r;
      } else {
        partner = r;
      }
    }

    final phase = (mine != null && partner != null)
        ? PromptPhase.revealed
        : (mine != null ? PromptPhase.waiting : PromptPhase.answer);

    state = state.copyWith(
      phase: phase,
      myResponse: mine,
      partnerResponse: partner,
    );
  }

  Future<void> submit(String text) async {
    final prompt = state.prompt;
    final answer = text.trim();
    if (prompt == null || answer.isEmpty || state.submitting) return;
    state = state.copyWith(submitting: true);
    try {
      await _repo.submitResponse(
          promptId: prompt.id, userId: _me, response: answer);
      await _refreshResponses();
    } finally {
      if (mounted) state = state.copyWith(submitting: false);
    }
  }

  Future<void> requestNew() async {
    final prompt = state.prompt;
    if (prompt == null || state.requesting) return;
    state = state.copyWith(requesting: true);
    try {
      final recent = await _repo.recentContents(_coupleId);
      final avoid = {...recent, prompt.content};
      final pick = PromptBank.pick(avoid);
      final fresh = await _repo.requestNew(pick.content, pick.category);
      if (!mounted) return;
      // Reset to answer phase for the new prompt and re-point the channel.
      state = PromptState(prompt: fresh, phase: PromptPhase.answer);
      _openChannel(fresh.id);
      await _refreshResponses();
    } finally {
      if (mounted) state = state.copyWith(requesting: false);
    }
  }

  Future<void> toggleReaction(String responseId, String emoji) async {
    final target = state.partnerResponse;
    if (target == null || target.id != responseId) return;
    final already =
        target.reactions.any((r) => r.userId == _me && r.emoji == emoji);
    try {
      await _repo.toggleReaction(
        responseId: responseId,
        userId: _me,
        emoji: emoji,
        alreadyReacted: already,
      );
      await _refreshResponses();
    } catch (_) {
      // best-effort; realtime will reconcile
    }
  }

  @override
  void dispose() {
    _channel?.let((c) => _repo.removeChannel(c));
    super.dispose();
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// autoDispose.family → one controller per couple; leaving the prompt screen
/// tears down the realtime channel.
final promptControllerProvider = StateNotifierProvider.autoDispose
    .family<PromptController, PromptState, String>((ref, coupleId) {
  return PromptController(ref.watch(promptRepositoryProvider), coupleId);
});
