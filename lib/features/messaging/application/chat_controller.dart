import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'dart:io';

import '../../auth/application/auth_providers.dart';
import '../data/chat_message.dart';
import '../data/message_repository.dart';
import '../data/storage_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepository(ref.watch(supabaseClientProvider)),
);

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepository(ref.watch(supabaseClientProvider)),
);

/// Immutable chat state.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.replyingToId,
  });

  final List<ChatMessage> messages;
  final bool loading;
  final String? replyingToId;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    Object? replyingToId = _sentinel,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      replyingToId: replyingToId == _sentinel
          ? this.replyingToId
          : replyingToId as String?,
    );
  }

  static const _sentinel = Object();
}

/// Chat controller for one couple. Owns the realtime channel and disposes it
/// when the provider is torn down (autoDispose → leaving the screen).
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._storage, this._coupleId, this._uuid)
      : super(const ChatState()) {
    _init();
  }

  final MessageRepository _repo;
  final StorageRepository _storage;
  final String _coupleId;
  final Uuid _uuid;
  RealtimeChannel? _channel;

  String get _me => _repo.currentUserId ?? '';

  Future<void> _init() async {
    final messages = await _repo.fetchMessages(_coupleId);
    if (!mounted) return;
    state = ChatState(messages: messages, loading: false);

    _channel = _repo.channel(
      _coupleId,
      onMessageInsert: _onInsert,
      onMessageUpdate: _onUpdate,
      onReactionChange: _reconcileReactions,
    )..subscribe();

    _markPartnerMessagesRead();
  }

  // ---- Realtime handlers ----

  void _onInsert(Map<String, dynamic> row) {
    final incoming = ChatMessage.fromRow(row);
    final idx = state.messages.indexWhere((m) => m.id == incoming.id);
    if (idx >= 0) {
      // Echo of our own optimistic message (same client id) — dedup: merge,
      // preserving any local reactions we already show.
      final merged = incoming.copyWith(reactions: state.messages[idx].reactions);
      state = state.copyWith(messages: _replaceAt(idx, merged));
    } else {
      state = state.copyWith(messages: [...state.messages, incoming]);
      if (incoming.senderId != _me) _markPartnerMessagesRead();
    }
  }

  void _onUpdate(Map<String, dynamic> row) {
    final incoming = ChatMessage.fromRow(row);
    final idx = state.messages.indexWhere((m) => m.id == incoming.id);
    if (idx < 0) return;
    // Update payload lacks embedded reactions — keep the ones we have.
    final existing = state.messages[idx];
    final merged = existing.copyWith(
      deletedFor: incoming.deletedFor,
      unsent: incoming.unsent,
      deliveryState: incoming.deliveryState,
    );
    state = state.copyWith(messages: _replaceAt(idx, merged));
  }

  Future<void> _reconcileReactions() async {
    final fresh = await _repo.fetchMessages(_coupleId);
    if (!mounted) return;
    // Keep any local-only messages still in flight (sending/failed) not yet in DB.
    final dbIds = fresh.map((m) => m.id).toSet();
    final localOnly = state.messages.where((m) =>
        !dbIds.contains(m.id) &&
        (m.deliveryState == DeliveryState.sending ||
            m.deliveryState == DeliveryState.failed));
    state = state.copyWith(messages: [...fresh, ...localOnly]);
  }

  // ---- Actions ----

  Future<void> sendText(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    final id = _uuid.v4();
    final replyToId = state.replyingToId;

    // OPTIMISTIC: show instantly, never wait for the echo.
    final optimistic = ChatMessage(
      id: id,
      senderId: _me,
      type: 'text',
      content: text,
      createdAt: DateTime.now(),
      replyToId: replyToId,
      deliveryState: DeliveryState.sending,
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      replyingToId: null,
    );

    try {
      await _repo.sendText(
        id: id,
        coupleId: _coupleId,
        senderId: _me,
        content: text,
        replyToId: replyToId,
      );
      _setDeliveryState(id, DeliveryState.sent);
    } catch (_) {
      _setDeliveryState(id, DeliveryState.failed);
    }
  }

  /// Optimistic voice send: show a local bubble, upload the file, then insert.
  Future<void> sendVoice(String localFilePath) async {
    final id = _uuid.v4();
    final path = _storage.voicePath(_coupleId, id);
    _appendOptimisticMedia(id: id, type: 'voice', localPath: localFilePath);
    await _uploadAndInsert(
      id: id,
      type: 'voice',
      objectPath: path,
      file: File(localFilePath),
      contentType: 'audio/mp4',
    );
  }

  /// Optimistic photo send: compress, show local bubble, upload, then insert.
  Future<void> sendImage(String localFilePath) async {
    final id = _uuid.v4();
    _appendOptimisticMedia(id: id, type: 'image', localPath: localFilePath);
    final compressed = await _storage.compressImage(localFilePath, id);
    // Swap preview to the compressed file so bubble matches what we upload.
    _setLocalPath(id, compressed.path);
    final path = _storage.photoPath(_coupleId, id);
    await _uploadAndInsert(
      id: id,
      type: 'image',
      objectPath: path,
      file: compressed,
      contentType: 'image/jpeg',
    );
  }

  void _appendOptimisticMedia({
    required String id,
    required String type,
    required String localPath,
  }) {
    final optimistic = ChatMessage(
      id: id,
      senderId: _me,
      type: type,
      content: null,
      createdAt: DateTime.now(),
      replyToId: state.replyingToId,
      deliveryState: DeliveryState.sending,
      localPath: localPath,
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      replyingToId: null,
    );
  }

  Future<void> _uploadAndInsert({
    required String id,
    required String type,
    required String objectPath,
    required File file,
    required String contentType,
  }) async {
    final idx = state.messages.indexWhere((m) => m.id == id);
    final replyToId = idx >= 0 ? state.messages[idx].replyToId : null;
    try {
      await _storage.upload(objectPath, file, contentType);
      await _repo.sendMedia(
        id: id,
        coupleId: _coupleId,
        senderId: _me,
        type: type,
        path: objectPath,
        replyToId: replyToId,
      );
      // Set content to the object path so the bubble can sign-on-view.
      final at = state.messages.indexWhere((m) => m.id == id);
      if (at >= 0) {
        state = state.copyWith(
          messages: _replaceAt(
            at,
            state.messages[at]
                .copyWith(content: objectPath, deliveryState: DeliveryState.sent),
          ),
        );
      }
    } catch (_) {
      _setDeliveryState(id, DeliveryState.failed);
    }
  }

  void _setLocalPath(String id, String localPath) {
    final idx = state.messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    state = state.copyWith(
        messages: _replaceAt(idx, state.messages[idx].copyWith(localPath: localPath)));
  }

  Future<void> retry(String messageId) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    _setDeliveryState(messageId, DeliveryState.sending);

    if (m.isText) {
      try {
        await _repo.sendText(
          id: m.id,
          coupleId: _coupleId,
          senderId: _me,
          content: m.content ?? '',
          replyToId: m.replyToId,
        );
        _setDeliveryState(messageId, DeliveryState.sent);
      } catch (_) {
        _setDeliveryState(messageId, DeliveryState.failed);
      }
      return;
    }

    // Media retry: re-upload the local file (if still present) and re-insert.
    final localPath = m.localPath;
    if (localPath == null) {
      _setDeliveryState(messageId, DeliveryState.failed);
      return;
    }
    final objectPath = m.isVoice
        ? _storage.voicePath(_coupleId, m.id)
        : _storage.photoPath(_coupleId, m.id);
    await _uploadAndInsert(
      id: m.id,
      type: m.type,
      objectPath: objectPath,
      file: File(localPath),
      contentType: m.isVoice ? 'audio/mp4' : 'image/jpeg',
    );
  }

  void setReplyingTo(String? messageId) =>
      state = state.copyWith(replyingToId: messageId);

  Future<void> toggleReaction(String messageId, String emoji) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    final already =
        m.reactions.any((r) => r.userId == _me && r.emoji == emoji);

    // Optimistic reaction update; realtime reconcile follows.
    final nextReactions = already
        ? m.reactions
            .where((r) => !(r.userId == _me && r.emoji == emoji))
            .toList()
        : [...m.reactions, MessageReaction(userId: _me, emoji: emoji)];
    state = state.copyWith(
        messages: _replaceAt(idx, m.copyWith(reactions: nextReactions)));

    try {
      await _repo.toggleReaction(
        messageId: messageId,
        userId: _me,
        emoji: emoji,
        alreadyReacted: already,
      );
    } catch (_) {
      _reconcileReactions();
    }
  }

  Future<void> deleteForMe(String messageId) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    state = state.copyWith(
      messages: _replaceAt(idx, m.copyWith(deletedFor: [...m.deletedFor, _me])),
    );
    await _repo.deleteForMe(
      messageId: messageId,
      currentDeletedFor: m.deletedFor,
      userId: _me,
    );
  }

  Future<void> unsend(String messageId) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    state = state.copyWith(
      messages: _replaceAt(idx, state.messages[idx].copyWith(unsent: true)),
    );
    await _repo.unsend(messageId);
  }

  Future<void> _markPartnerMessagesRead() async {
    final ids = state.messages
        .where((m) =>
            m.senderId != _me && m.deliveryState != DeliveryState.read)
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    await _repo.markState(ids, DeliveryState.read);
  }

  void _setDeliveryState(String id, DeliveryState s) {
    final idx = state.messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    state = state.copyWith(
        messages: _replaceAt(idx, state.messages[idx].copyWith(deliveryState: s)));
  }

  List<ChatMessage> _replaceAt(int idx, ChatMessage m) {
    final list = [...state.messages];
    list[idx] = m;
    return list;
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

/// autoDispose.family → one controller per couple; leaving chat disposes it and
/// tears down the realtime channel (clean lifecycle).
final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>((ref, coupleId) {
  return ChatController(
    ref.watch(messageRepositoryProvider),
    ref.watch(storageRepositoryProvider),
    coupleId,
    const Uuid(),
  );
});
