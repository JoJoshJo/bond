import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/creature_chat_controller.dart';
import '../application/creature_controller.dart';
import '../../ai/data/ai_models.dart';
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
          Text('Usora', style: AppText.title),
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
    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
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
                    style: AppText.bodyMedium.copyWith(
                        color: mine ? AppColors.onMint : AppColors.ink)),
          ),
        ),
        if (m.movies.isNotEmpty) _movieRow(m.movies),
        if (m.places.isNotEmpty) _placeRow(m.places),
      ],
    );
  }

  Widget _placeRow(List<PlaceCard> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _placeCard(places[i]),
          ),
        ),
        Text('Places powered by Foursquare.',
            style: AppText.bodySmall.copyWith(color: AppColors.inkFaint)),
      ],
    );
  }

  Widget _placeCard(PlaceCard p) {
    return GestureDetector(
      onTap: () => _openPlace(p),
      child: SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 110,
                width: 170,
                child: p.photoUrl == null
                    ? Container(
                        color: AppColors.surfaceAlt,
                        child: Icon(Icons.place_outlined,
                            color: AppColors.inkFaint),
                      )
                    : Image.network(p.photoUrl!, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                            color: AppColors.surfaceAlt,
                            child: Icon(Icons.place_outlined,
                                color: AppColors.inkFaint))),
              ),
            ),
            const SizedBox(height: 4),
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text(
              [
                if (p.category.isNotEmpty) p.category,
                if (p.distance != null) _dist(p.distance!),
              ].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _dist(int m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(1)} km'
      : '$m m';

  void _openPlace(PlaceCard p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(p.photoUrl!,
                    height: 160, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox.shrink()),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(p.name, style: AppText.title),
            const SizedBox(height: 4),
            Text(
              [
                if (p.category.isNotEmpty) p.category,
                if (p.rating != null) '⭐ ${p.rating}',
                if (p.distance != null) _dist(p.distance!),
              ].join('  ·  '),
              style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
            ),
            if (p.address.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(p.address, style: AppText.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.lg),
            BondButton(
              label: 'Open in Maps',
              icon: Icons.map_outlined,
              onPressed: () => _openInMaps(p),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(PlaceCard p) async {
    final q = (p.lat != null && p.lng != null)
        ? '${p.lat},${p.lng}'
        : Uri.encodeComponent(p.name);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _movieRow(List<MovieCard> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _movieCard(movies[i]),
          ),
        ),
        // Required by TMDB terms of use: logo + disclaimer.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset('assets/images/tmdb_logo.svg', height: 14),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Uses the TMDB API but is not endorsed or certified by TMDB.',
                style: AppText.bodySmall.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _movieCard(MovieCard m) {
    return GestureDetector(
      onTap: () => _openMovie(m),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: m.posterUrl == null
                    ? Container(
                        color: AppColors.surfaceAlt,
                        child: Icon(Icons.movie_outlined,
                            color: AppColors.inkFaint),
                      )
                    : Image.network(m.posterUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 4),
            Text(m.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text(
              [
                if (m.year.isNotEmpty) m.year,
                if (m.rating > 0) '⭐ ${m.rating}',
              ].join('  ·  '),
              style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _openMovie(MovieCard m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.posterUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(m.posterUrl!, width: 100),
                  ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, style: AppText.title),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (m.year.isNotEmpty) m.year,
                          if (m.rating > 0) '⭐ ${m.rating}',
                        ].join('  ·  '),
                        style: AppText.bodySmall
                            .copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (m.overview.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(m.overview, style: AppText.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
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
                hintText: _listening ? 'Listening…' : 'Say something to Usora',
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
              child: Padding(
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
