import 'package:flutter/foundation.dart';

/// Delivery lifecycle. `failed` is local-only (insert error → tap to retry).
enum DeliveryState { sending, sent, delivered, read, failed }

DeliveryState deliveryFromString(String? s) => switch (s) {
      'sending' => DeliveryState.sending,
      'sent' => DeliveryState.sent,
      'delivered' => DeliveryState.delivered,
      'read' => DeliveryState.read,
      _ => DeliveryState.sent,
    };

/// One reaction on a message.
@immutable
class MessageReaction {
  const MessageReaction({
    required this.userId,
    required this.emoji,
  });

  final String userId;
  final String emoji;
}

/// An immutable chat message. `id` is client-generated at send time and reused
/// as the DB primary key, so the realtime echo dedups by matching this id.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.content,
    required this.createdAt,
    this.replyToId,
    this.deletedFor = const [],
    this.unsent = false,
    this.deliveryState = DeliveryState.sent,
    this.reactions = const [],
  });

  final String id;
  final String senderId;
  final String type; // 'text' for now
  final String? content;
  final DateTime createdAt;
  final String? replyToId;
  final List<String> deletedFor;
  final bool unsent;
  final DeliveryState deliveryState;
  final List<MessageReaction> reactions;

  bool isMine(String uid) => senderId == uid;
  bool isDeletedForMe(String uid) => deletedFor.contains(uid);

  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    final rawDeleted = row['deleted_for'];
    final deleted = switch (rawDeleted) {
      final List<dynamic> l => l.map((e) => e.toString()).toList(),
      _ => <String>[],
    };
    final rawReactions = row['message_reactions'];
    final reactions = switch (rawReactions) {
      final List<dynamic> l => l
          .map((r) => MessageReaction(
                userId: (r as Map<String, dynamic>)['user_id'] as String,
                emoji: r['emoji'] as String,
              ))
          .toList(),
      _ => <MessageReaction>[],
    };

    return ChatMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      type: (row['type'] as String?) ?? 'text',
      content: row['content'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      replyToId: row['reply_to_id'] as String?,
      deletedFor: deleted,
      unsent: (row['unsent'] as bool?) ?? false,
      deliveryState: deliveryFromString(row['delivery_state'] as String?),
      reactions: reactions,
    );
  }

  ChatMessage copyWith({
    List<String>? deletedFor,
    bool? unsent,
    DeliveryState? deliveryState,
    List<MessageReaction>? reactions,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      type: type,
      content: content,
      createdAt: createdAt,
      replyToId: replyToId,
      deletedFor: deletedFor ?? this.deletedFor,
      unsent: unsent ?? this.unsent,
      deliveryState: deliveryState ?? this.deliveryState,
      reactions: reactions ?? this.reactions,
    );
  }
}
