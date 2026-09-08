import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';

/// Chat composer: optional reply preview + text field + send button.
class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.onSend,
    this.replyingToText,
    this.onCancelReply,
  });

  final void Function(String text) onSend;
  final String? replyingToText;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? AppSpacing.sm
            : AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToText != null) _replyBar(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle:
                        AppText.bodyMedium.copyWith(color: AppColors.inkFaint),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _sendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _replyBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppColors.mint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to',
                    style: AppText.bodySmall.copyWith(color: AppColors.mintDeep)),
                Text(widget.replyingToText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.inkMuted),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _sendButton() {
    return Material(
      color: AppColors.mint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _send,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Icon(Icons.arrow_upward_rounded, color: AppColors.onMint),
        ),
      ),
    );
  }
}
