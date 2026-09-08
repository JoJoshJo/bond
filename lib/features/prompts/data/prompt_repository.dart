import 'package:supabase_flutter/supabase_flutter.dart';

import 'prompt_models.dart';

/// Data access for the daily prompt. Prompt get-or-create + request-new go
/// through the vetted RPCs; answering/reading responses ride the existing
/// prompt_responses mutual-lock RLS (untouched here).
class PromptRepository {
  PromptRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Recent prompt contents for the couple, to avoid repeats when picking.
  Future<Set<String>> recentContents(String coupleId, {int limit = 15}) async {
    final rows = await _client
        .from('prompts')
        .select('content')
        .eq('couple_id', coupleId)
        .order('generated_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['content'] as String)
        .toSet();
  }

  Future<DailyPrompt> getOrCreateDaily(String content, String category) async {
    final rows = await _client.rpc('get_or_create_daily_prompt',
        params: {'p_content': content, 'p_category': category}) as List<dynamic>;
    return DailyPrompt.fromRow(rows.first as Map<String, dynamic>);
  }

  Future<DailyPrompt> requestNew(String content, String category) async {
    final rows = await _client.rpc('request_new_prompt',
        params: {'p_content': content, 'p_category': category}) as List<dynamic>;
    return DailyPrompt.fromRow(rows.first as Map<String, dynamic>);
  }

  /// Insert my answer. Reveal is derived from the RLS-gated read below.
  Future<void> submitResponse({
    required String promptId,
    required String userId,
    required String response,
  }) async {
    await _client.from('prompt_responses').insert({
      'prompt_id': promptId,
      'user_id': userId,
      'response': response,
    });
  }

  /// Update my own answer (allowed only pre-reveal, gated in the controller).
  /// RLS lets a user update only their own row.
  Future<void> updateResponse({
    required String promptId,
    required String userId,
    required String response,
  }) async {
    await _client
        .from('prompt_responses')
        .update({'response': response})
        .eq('prompt_id', promptId)
        .eq('user_id', userId);
  }

  /// Responses visible to me under the mutual-lock: always my own; the
  /// partner's only once both exist. So `length == 2` ⇒ reveal.
  Future<List<PromptResponse>> fetchResponses(String promptId) async {
    final rows = await _client
        .from('prompt_responses')
        .select('*, prompt_response_reactions(user_id, emoji)')
        .eq('prompt_id', promptId);
    return (rows as List<dynamic>)
        .map((r) => PromptResponse.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleReaction({
    required String responseId,
    required String userId,
    required String emoji,
    required bool alreadyReacted,
  }) async {
    if (alreadyReacted) {
      await _client
          .from('prompt_response_reactions')
          .delete()
          .eq('response_id', responseId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
    } else {
      await _client.from('prompt_response_reactions').insert({
        'response_id': responseId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  /// Realtime for reveal + reactions on this prompt.
  RealtimeChannel channel(
    String promptId, {
    required void Function() onResponseChange,
    required void Function() onReactionChange,
  }) {
    return _client
        .channel('prompt_$promptId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'prompt_responses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'prompt_id',
            value: promptId,
          ),
          callback: (_) => onResponseChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prompt_response_reactions',
          callback: (_) => onReactionChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
