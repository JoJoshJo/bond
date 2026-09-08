import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../data/chat_message.dart';
import '../../../../core/storage/storage_repository.dart';
import 'image_bubble.dart';
import 'voice_bubble.dart';

/// A single chat bubble: mine (mint, right) vs partner (surface, left), with an
/// optional quoted reply, reaction cluster, and delivery ticks for my messages.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.storage,
    this.repliedTo,
    this.onLongPress,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final String currentUserId;
  final StorageRepository storage;
  final ChatMessage? repliedTo;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.unsent) return _tombstone();

    final fg = isMine ? AppColors.onMint : AppColors.ink;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: align,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: message.isImage ? _imageContent() : _framedContent(context, fg),
          ),
          if (message.reactions.isNotEmpty) _reactions(),
          if (isMine) _statusRow(),
        ],
      ),
    );
  }

  /// Text/voice sit inside the colored, rounded bubble.
  Widget _framedContent(BuildContext context, Color fg) {
    final bg = isMine ? AppColors.mint : AppColors.surface;
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.xs),
          bottomRight: Radius.circular(isMine ? AppRadius.xs : AppRadius.lg),
        ),
        border: isMine ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (repliedTo != null) _replyPreview(fg),
          if (message.isVoice)
            VoiceBubble(message: message, isMine: isMine, storage: storage)
          else
            Text(message.content ?? '',
                style: AppText.bodyMedium.copyWith(color: fg)),
        ],
      ),
    );
  }

  /// Images render edge-to-edge (no colored frame).
  Widget _imageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (repliedTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _replyPreview(AppColors.ink),
          ),
        ImageBubble(message: message, storage: storage),
      ],
    );
  }

  Widget _replyPreview(Color fg) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: (isMine ? Colors.white : AppColors.mintWash).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: fg.withValues(alpha: 0.4), width: 2)),
      ),
      child: Text(
        repliedTo!.snippet ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.bodySmall.copyWith(color: fg.withValues(alpha: 0.85)),
      ),
    );
  }

  Widget _reactions() {
    // Group by emoji with counts.
    final counts = <String, int>{};
    for (final r in message.reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('${e.key} ${e.value > 1 ? e.value : ''}'.trim(),
                style: AppText.bodySmall),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusRow() {
    final (icon, color) = switch (message.deliveryState) {
      DeliveryState.sending => (Icons.schedule, AppColors.inkFaint),
      DeliveryState.sent => (Icons.check, AppColors.inkFaint),
      DeliveryState.delivered => (Icons.done_all, AppColors.inkFaint),
      DeliveryState.read => (Icons.done_all, AppColors.mint),
      DeliveryState.failed => (Icons.error_outline, AppColors.error),
    };
    final failed = message.deliveryState == DeliveryState.failed;
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 2),
      child: GestureDetector(
        onTap: failed ? onRetry : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed)
              Text('Tap to retry  ',
                  style: AppText.bodySmall.copyWith(color: AppColors.error)),
            Icon(icon, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _tombstone() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text('This message was unsent',
              style: AppText.bodySmall.copyWith(
                  fontStyle: FontStyle.italic, color: AppColors.inkFaint)),
        ),
      ),
    );
  }
}
