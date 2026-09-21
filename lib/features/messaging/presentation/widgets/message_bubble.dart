import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../data/chat_message.dart';
import '../../../../core/storage/storage_repository.dart';
import 'image_bubble.dart';
import 'voice_bubble.dart';

/// Bubble corner radius — soft and round.
const double _kBubbleRadius = 22;

/// The "tail" corner on the sender side of the last bubble in a run.
const double _kTailRadius = 8;

/// A single chat bubble: mine (brand green, white text, right) vs partner
/// (white, thin border + soft shadow, left), with an optional quoted reply,
/// reaction cluster, and — on the last bubble of a run — a quiet timestamp plus
/// read receipt (mine).
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
    this.showMeta = true,
    this.tail = true,
  });

  final ChatMessage message;
  final bool isMine;
  final String currentUserId;
  final StorageRepository storage;
  final ChatMessage? repliedTo;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  /// Show the time + receipt row (true on the last bubble of a sender run, and
  /// always when a send failed so "Tap to retry" is reachable).
  final bool showMeta;

  /// Draw the small sender-side tail corner (last bubble of a run).
  final bool tail;

  bool get _failed => message.deliveryState == DeliveryState.failed;

  @override
  Widget build(BuildContext context) {
    if (message.unsent) return _tombstone();

    final fg = isMine ? AppColors.onChatMine : AppColors.ink;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      // Tighter within a run, a little air after its last bubble.
      padding: EdgeInsets.only(top: 2, bottom: tail ? AppSpacing.sm : 2),
      child: Column(
        crossAxisAlignment: align,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: message.isImage ? _imageContent() : _framedContent(context, fg),
          ),
          if (message.reactions.isNotEmpty) _reactions(),
          if (showMeta || _failed) _metaRow(context),
        ],
      ),
    );
  }

  BorderRadius get _radius {
    const r = Radius.circular(_kBubbleRadius);
    const t = Radius.circular(_kTailRadius);
    return BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: (tail && !isMine) ? t : r,
      bottomRight: (tail && isMine) ? t : r,
    );
  }

  /// Text/voice sit inside the colored, rounded bubble.
  Widget _framedContent(BuildContext context, Color fg) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isMine ? AppColors.chatMine : AppColors.surface,
        borderRadius: _radius,
        // Partner bubbles are white on a white screen: a hairline border plus a
        // soft shadow lifts them off it. Mine are solid green — no border.
        border: isMine ? null : Border.all(color: AppColors.border),
        boxShadow: isMine
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (repliedTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _replyPreview(AppColors.ink, onPlain: true),
          ),
        ImageBubble(message: message, storage: storage),
      ],
    );
  }

  /// Quoted reply. Inside MY green bubble it sits on a darker overlay so its
  /// white text keeps contrast; elsewhere it's a soft mint wash with ink text.
  Widget _replyPreview(Color fg, {bool onPlain = false}) {
    final onGreen = isMine && !onPlain;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: onGreen
            ? Colors.black.withValues(alpha: 0.16)
            : AppColors.mintWash,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
            left: BorderSide(
                color: onGreen ? AppColors.onChatMine : AppColors.chatMine,
                width: 2)),
      ),
      child: Text(
        repliedTo!.snippet ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.bodySmall
            .copyWith(color: onGreen ? AppColors.onChatMine : AppColors.ink),
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
              color: AppColors.surface,
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

  /// Quiet meta: time for both sides, plus a small receipt tick for mine.
  /// Kept quiet by size + placement, NOT by a light color: this text can sit
  /// directly on the doodle field, where inkMuted would dip below 4.5:1 over a
  /// stroke (≈4.0:1). ink stays ≥11.5:1 even over the densest doodle.
  Widget _metaRow(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(message.createdAt.toLocal()));
    final quiet = AppText.bodySmall.copyWith(
        color: AppColors.ink, fontSize: 11.5, fontWeight: FontWeight.w400);

    final receipt = !isMine
        ? null
        : switch (message.deliveryState) {
            DeliveryState.sending => (Icons.schedule, AppColors.inkMuted),
            DeliveryState.sent => (Icons.check, AppColors.inkMuted),
            DeliveryState.delivered => (Icons.done_all, AppColors.inkMuted),
            DeliveryState.read => (Icons.done_all, AppColors.chatMine),
            DeliveryState.failed => (Icons.error_outline, AppColors.error),
          };

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
      child: GestureDetector(
        onTap: _failed ? onRetry : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_failed)
              Text('Tap to retry  ',
                  style: AppText.bodySmall.copyWith(color: AppColors.error))
            else
              Text(time, style: quiet),
            if (receipt != null) ...[
              const SizedBox(width: 4),
              Icon(receipt.$1, size: 13, color: receipt.$2),
            ],
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_kBubbleRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('This message was unsent',
              style: AppText.bodySmall.copyWith(
                  fontStyle: FontStyle.italic, color: AppColors.inkMuted)),
        ),
      ),
    );
  }
}
