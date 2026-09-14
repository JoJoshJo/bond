import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/chat_controller.dart';
import '../data/chat_message.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';

const _reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

/// The couple's private text chat — the linked landing for now.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.coupleId, required this.coupleName});

  final String coupleId;
  final String coupleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider(coupleId));
    final controller = ref.read(chatControllerProvider(coupleId).notifier);
    final me = ref.read(messageRepositoryProvider).currentUserId ?? '';
    final storage = ref.read(storageRepositoryProvider);

    // Visible = not "deleted for me", oldest→newest.
    final visible =
        state.messages.where((m) => !m.isDeletedForMe(me)).toList();
    final reversed = visible.reversed.toList();

    String? replyingText;
    if (state.replyingToId != null) {
      replyingText = _findById(state.messages, state.replyingToId!)?.snippet;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(coupleName, style: AppText.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.loading
                  ? const BondSkeletonChat()
                  : reversed.isEmpty
                      ? _empty()
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          itemCount: reversed.length,
                          itemBuilder: (context, i) {
                            final m = reversed[i];
                            return MessageBubble(
                              message: m,
                              isMine: m.isMine(me),
                              currentUserId: me,
                              storage: storage,
                              repliedTo: m.replyToId == null
                                  ? null
                                  : _findById(state.messages, m.replyToId!),
                              onLongPress: () =>
                                  _showActions(context, controller, m, me),
                              onRetry: () => controller.retry(m.id),
                            );
                          },
                        ),
            ),
            MessageInput(
              onSendText: controller.sendText,
              onSendVoice: controller.sendVoice,
              onSendImage: controller.sendImage,
              replyingToText: replyingText,
              onCancelReply: () => controller.setReplyingTo(null),
            ),
          ],
        ),
      ),
    );
  }

  ChatMessage? _findById(List<ChatMessage> list, String id) {
    for (final m in list) {
      if (m.id == id) return m;
    }
    return null;
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 44, color: AppColors.mint),
            const SizedBox(height: AppSpacing.md),
            Text('Say hello 💛',
                textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            Text('This is the start of your private space.',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }

  void _showActions(
    BuildContext context,
    ChatController controller,
    ChatMessage m,
    String me,
  ) {
    final isMine = m.isMine(me);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _reactionEmojis.map((e) {
                  return GestureDetector(
                    onTap: () {
                      controller.toggleReaction(m.id, e);
                      Navigator.of(ctx).pop();
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            _action(ctx, Icons.reply, 'Reply', () {
              controller.setReplyingTo(m.id);
              Navigator.of(ctx).pop();
            }),
            if (m.isText && m.content != null)
              _action(ctx, Icons.copy, 'Copy', () {
                Clipboard.setData(ClipboardData(text: m.content!));
                Navigator.of(ctx).pop();
              }),
            _action(ctx, Icons.visibility_off_outlined, 'Delete for me', () {
              controller.deleteForMe(m.id);
              Navigator.of(ctx).pop();
            }),
            if (isMine && !m.unsent)
              _action(ctx, Icons.undo, 'Unsend for both', () {
                controller.unsend(m.id);
                Navigator.of(ctx).pop();
              }, danger: true),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppColors.error : AppColors.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: AppText.bodyLarge.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
