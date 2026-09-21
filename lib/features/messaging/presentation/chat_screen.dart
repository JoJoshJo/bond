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

/// Doodle strength + fade for the partner chat — tune the look in one place.
const double _chatDoodleOpacity = DoodleBackground.defaultOpacity;

/// Space kept doodle-free above the bottom inset: the composer's ~72pt resting
/// height + a 24pt margin (covers a doodle's ~8pt overhang past its center and
/// leaves ~16pt of clean white above the composer).
const double _composerReserve = 96;

/// How far the fade band spans (as a fraction of screen height) — same
/// softness as before, just positioned lower.
const double _fadeBand = 0.40;

/// The chat's downward fade, anchored to the composer's resting position so the
/// doodles carry well down the screen and dissolve just above the composer — on
/// any screen height / bottom inset.
DoodleFade _chatDoodleFade(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  final inset = MediaQuery.paddingOf(context).bottom;
  final end = ((h - (inset + _composerReserve)) / h).clamp(0.5, 0.95);
  final start = (end - _fadeBand).clamp(0.0, end - 0.05);
  return DoodleFade(start: start, end: end);
}

/// Local first-message starters for the empty state (label → draft). These are
/// deliberately simple local strings: the daily-prompt system is a private
/// answer-then-reveal mechanic, so it isn't piped into open chat.
const _starters = <(IconData, String, String)>[
  (Icons.sentiment_satisfied_alt_rounded, 'What made you smile today?',
      'What made you smile today? 😊'),
  (Icons.wb_sunny_outlined, 'Send a good-morning',
      'Good morning ☀️ Hope your day is a gentle one.'),
];

/// The couple's private text chat (the "Chat" tab — partner messaging).
///
/// A faint doodle field fades out down the screen so the conversation and the
/// composer sit on clean color with no header fill or divider lines.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.coupleId, required this.coupleName});

  final String coupleId;
  final String coupleName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  // The composer's draft lives here so empty-state starters can pre-fill it.
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();

  @override
  void dispose() {
    _draft.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  void _prefill(String text) {
    _draft
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _draftFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = widget.coupleId;
    final state = ref.watch(chatControllerProvider(coupleId));
    final controller = ref.read(chatControllerProvider(coupleId).notifier);
    final me = ref.read(messageRepositoryProvider).currentUserId ?? '';
    final storage = ref.read(storageRepositoryProvider);

    // Themes with a doodle token (mint) get the doodles on pure white; the
    // rest keep their existing plain background.
    final doodle = AppColors.doodle;
    final base = doodle != null ? AppColors.surface : AppColors.bg;

    // Visible = not "deleted for me", oldest→newest, then grouped into rows.
    final visible =
        state.messages.where((m) => !m.isDeletedForMe(me)).toList();
    final rows = _buildRows(visible).reversed.toList();

    String? replyingText;
    if (state.replyingToId != null) {
      replyingText = _findById(state.messages, state.replyingToId!)?.snippet;
    }

    return Stack(
      children: [
        // Full-screen and OUTSIDE the Scaffold body: unaffected by keyboard
        // insets and list scrolling, so it's painted once and stays cached.
        Positioned.fill(
          child: DoodleBackground(
            base: base,
            color: doodle,
            opacity: _chatDoodleOpacity,
            fade: _chatDoodleFade(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            // No fill, no divider, no scroll-under tint: the title sits right
            // on the doodles.
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(widget.coupleName,
                style: AppText.title.copyWith(color: AppColors.anchor)),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: state.loading
                      ? const BondSkeletonChat()
                      : rows.isEmpty
                          ? _empty()
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md),
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final row = rows[i];
                                if (row is DateTime) return _DayPill(day: row);
                                final entry = row as _MessageRow;
                                final m = entry.message;
                                return MessageBubble(
                                  message: m,
                                  isMine: m.isMine(me),
                                  currentUserId: me,
                                  storage: storage,
                                  showMeta: entry.lastInRun,
                                  tail: entry.lastInRun,
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
                  controller: _draft,
                  focusNode: _draftFocus,
                  background: base,
                  onSendText: controller.sendText,
                  onSendVoice: controller.sendVoice,
                  onSendImage: controller.sendImage,
                  replyingToText: replyingText,
                  onCancelReply: () => controller.setReplyingTo(null),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Chronological rows: a day separator (a [DateTime]) before the first
  /// message of each local day, then [_MessageRow]s marked with whether they
  /// end a sender run (same sender, same day, within 5 minutes of the next).
  static List<Object> _buildRows(List<ChatMessage> visible) {
    final rows = <Object>[];
    DateTime? prevDay;
    for (var i = 0; i < visible.length; i++) {
      final m = visible[i];
      final local = m.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (prevDay != day) {
        rows.add(day);
        prevDay = day;
      }
      final next = i + 1 < visible.length ? visible[i + 1] : null;
      var lastInRun = true;
      if (next != null) {
        final nl = next.createdAt.toLocal();
        final sameDay =
            nl.year == local.year && nl.month == local.month && nl.day == local.day;
        lastInRun = !(next.senderId == m.senderId &&
            sameDay &&
            nl.difference(local).inMinutes < 5);
      }
      rows.add(_MessageRow(m, lastInRun: lastInRun));
    }
    return rows;
  }

  ChatMessage? _findById(List<ChatMessage> list, String id) {
    for (final m in list) {
      if (m.id == id) return m;
    }
    return null;
  }

  Widget _empty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 40, color: AppColors.chatMine),
            const SizedBox(height: AppSpacing.md),
            Text('This is your space',
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(color: AppColors.anchor)),
            const SizedBox(height: AppSpacing.xs),
            // ink, not inkMuted: this line can sit on the (fading) doodles.
            Text('Just the two of you. Say the first thing.',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: AppColors.ink)),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (icon, label, draft) in _starters)
                  _StarterChip(
                      icon: icon, label: label, onTap: () => _prefill(draft)),
              ],
            ),
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

/// One message in the grouped list, plus whether it ends its sender run (which
/// decides the bubble tail and the quiet time/receipt row).
class _MessageRow {
  const _MessageRow(this.message, {required this.lastInRun});
  final ChatMessage message;
  final bool lastInRun;
}

/// Soft centered day separator: "Today", "Yesterday", a weekday, or a date.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.day});

  final DateTime day;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _label {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final d = DateTime.utc(day.year, day.month, day.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return _weekdays[day.weekday - 1];
    final md = '${_months[day.month - 1]} ${day.day}';
    return day.year == now.year ? md : '$md, ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.mintWash,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          // anchor on mintWash ≈ 8.6:1 (inkMuted would be only 4.3:1 here).
          child: Text(_label,
              style: AppText.bodySmall.copyWith(
                  color: AppColors.anchor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// A tappable first-message starter: pre-fills the composer (never auto-sends).
class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.chatMine),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: AppText.label.copyWith(color: AppColors.chatMine)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
