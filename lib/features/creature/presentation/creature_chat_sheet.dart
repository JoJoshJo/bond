import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../application/creature_chat_controller.dart';
import '../application/creature_controller.dart';
import '../data/creature_chat_models.dart';
import '../data/creature_models.dart';
import 'creature_view.dart';

/// A little conversation surface WITH the creature. Type or hold-to-speak; it
/// replies in personality (tap-only, never unsolicited).
class CreatureChatSheet extends ConsumerStatefulWidget {
  const CreatureChatSheet({super.key, required this.coupleId});

  final String coupleId;

  static void open(BuildContext context, String coupleId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => CreatureChatSheet(coupleId: coupleId),
    );
  }

  @override
  ConsumerState<CreatureChatSheet> createState() => _CreatureChatSheetState();
}

class _CreatureChatSheetState extends ConsumerState<CreatureChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize();
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {
      // Voice unavailable → type-only; no error surfaced.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(creatureChatProvider(widget.coupleId).notifier).send(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechReady) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) => setState(() => _controller.text = r.recognizedWords),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(creatureChatProvider(widget.coupleId));
    ref.listen(creatureChatProvider(widget.coupleId), (_, _) => _scrollToBottom());
    final mood =
        ref.watch(creatureStateProvider(widget.coupleId)).asData?.value.mood ??
            CreatureMood.content;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            _header(mood),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.length,
                itemBuilder: (context, i) => _bubble(messages[i]),
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header(CreatureMood mood) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            height: 44,
            width: 44,
            child: FittedBox(child: CreatureView(mood: mood, size: 120)),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('BOND', style: AppText.title),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _bubble(CreatureChatMessage m) {
    final mine = !m.fromCreature;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppColors.mint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: m.thinking
            ? const Text('…', style: TextStyle(fontSize: 20))
            : Text(m.text,
                style: AppText.bodyMedium
                    .copyWith(color: mine ? AppColors.onMint : AppColors.ink)),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyMedium,
              decoration: InputDecoration(
                hintText: _listening ? 'Listening…' : 'Say something to BOND',
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
          if (_speechReady)
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                    _listening ? AppColors.error : AppColors.surfaceAlt,
                child: Icon(Icons.mic,
                    color: _listening ? Colors.white : AppColors.inkMuted),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Material(
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
          ),
        ],
      ),
    );
  }
}
