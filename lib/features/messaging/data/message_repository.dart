import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_message.dart';

/// Data access for couple chat. Inserts use a caller-supplied id so the
/// optimistic message and its realtime echo share one id (dedup by id).
class MessageRepository {
  MessageRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Initial load: newest-last, with reactions embedded.
  Future<List<ChatMessage>> fetchMessages(String coupleId,
      {int limit = 100}) async {
    final rows = await _client
        .from('messages')
        .select('*, message_reactions(user_id, emoji)')
        .eq('couple_id', coupleId)
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => ChatMessage.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single message row (used to hydrate a realtime insert with its
  /// reactions, or resolve a reply target not in memory).
  Future<ChatMessage?> fetchOne(String messageId) async {
    final row = await _client
        .from('messages')
        .select('*, message_reactions(user_id, emoji)')
        .eq('id', messageId)
        .maybeSingle();
    return row == null ? null : ChatMessage.fromRow(row);
  }

  /// Insert a text message with a client-provided id. Runs in the background of
  /// the optimistic append; throws on failure so the UI can mark it failed.
  Future<void> sendText({
    required String id,
    required String coupleId,
    required String senderId,
    required String content,
    String? replyToId,
  }) async {
    await _client.from('messages').insert({
      'id': id,
      'couple_id': coupleId,
      'sender_id': senderId,
      'type': 'text',
      'content': content,
      'reply_to_id': replyToId,
      'delivery_state': 'sent',
    });
  }

  /// Toggle a reaction: remove if this user already has this emoji, else add.
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
    required bool alreadyReacted,
  }) async {
    if (alreadyReacted) {
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
    } else {
      await _client.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  /// "Delete for me" — append this user to deleted_for.
  Future<void> deleteForMe({
    required String messageId,
    required List<String> currentDeletedFor,
    required String userId,
  }) async {
    final next = {...currentDeletedFor, userId}.toList();
    await _client
        .from('messages')
        .update({'deleted_for': next}).eq('id', messageId);
  }

  /// "Unsend for both".
  Future<void> unsend(String messageId) async {
    await _client.from('messages').update({'unsent': true}).eq('id', messageId);
  }

  /// Partner side: mark received messages delivered/read.
  Future<void> markState(List<String> messageIds, DeliveryState state) async {
    if (messageIds.isEmpty) return;
    await _client
        .from('messages')
        .update({'delivery_state': state.name})
        .inFilter('id', messageIds);
  }

  /// Realtime channel for this couple's messages + reactions. Caller subscribes
  /// with the provided callbacks and must `removeChannel` on dispose.
  RealtimeChannel channel(
    String coupleId, {
    required void Function(Map<String, dynamic> row) onMessageInsert,
    required void Function(Map<String, dynamic> row) onMessageUpdate,
    required void Function() onReactionChange,
  }) {
    return _client
        .channel('chat_$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (payload) => onMessageInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (payload) => onMessageUpdate(payload.newRecord),
        )
        // Reactions have no couple_id; RLS scopes them to our couple. We refetch
        // the affected message on any change rather than filter server-side.
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) => onReactionChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
