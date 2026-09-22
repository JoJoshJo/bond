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
import '../../calendar/application/calendar_providers.dart';
import '../../premium/presentation/paywall_screen.dart';
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
      final ok = await _speech.initialize(
        // Reset the button when the recognizer stops on its own (pause/timeout)
        // so hold-to-speak can never get stuck in the listening state.
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (err) {
          debugPrint('speech recognition error: $err');
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ok);
    } catch (e) {
      // Voice unavailable → type-only; mic stays hidden via _speechReady.
      debugPrint('speech init failed (mic hidden): $e');
      if (mounted) setState(() => _speechReady = false);
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
    // Keep the couple's calendar loaded while chatting, so a confirmed change
    // writes through the same controller and resolves against live events.
    ref.watch(calendarControllerProvider(widget.coupleId));
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
                itemBuilder: (context, i) => _bubble(messages[i], i),
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

  Widget _bubble(CreatureChatMessage m, int index) {
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
        if (m.sources.isNotEmpty) _sourceLinks(m.sources),
        if (m.proposal case final p?)
          _CalendarProposalCard(
            proposal: p,
            status: m.proposalStatus,
            error: m.proposalError,
            onYes: () => ref
                .read(creatureChatProvider(widget.coupleId).notifier)
                .confirmProposal(index),
            onNo: () => ref
                .read(creatureChatProvider(widget.coupleId).notifier)
                .declineProposal(index),
          ),
        if (m.showUpgrade)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: BondButton(
              label: 'See Usora+',
              icon: Icons.workspace_premium_rounded,
              fullWidth: false,
              variant: BondButtonVariant.secondary,
              onPressed: () => PaywallScreen.open(context),
            ),
          ),
      ],
    );
  }

  /// "Source:" links for web_search results — so the couple can sanity-check.
  Widget _sourceLinks(List<WebSourceRef> sources) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in sources) _SourceLink(source: s),
        ],
      ),
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
        Text('Places powered by Google',
            style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
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
          // Fits the full card: poster (120w @ 2:3 = 180) + gap + up-to-2-line
          // title + year/rating, plus the list's vertical padding — so nothing
          // clips at the bottom.
          height: 258,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => _movieCard(movies[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Required by TMDB terms of use: logo + disclaimer, below the card row.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset('assets/images/tmdb_logo.svg', height: 14),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Uses the TMDB API but is not endorsed or certified by TMDB.',
                style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
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
                maxLines: 2,
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
                    AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
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

/// Yes/No confirmation for a calendar change Usora proposed. Nothing is written
/// until Yes. Text is ink / forest green on white (never inkMuted).
class _CalendarProposalCard extends StatelessWidget {
  const _CalendarProposalCard({
    required this.proposal,
    required this.status,
    required this.onYes,
    required this.onNo,
    this.error,
  });

  final CalendarProposal proposal;
  final ProposalStatus status;

  /// DEV ONLY: raw save error, shown under "Nothing changed".
  final String? error;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final (heading, yesLabel, doneLabel) = switch (proposal.op) {
      CalendarOp.add => ('Add to your calendar?', 'Yes, add it', 'Added'),
      CalendarOp.update => ('Change this event?', 'Yes, change it', 'Updated'),
      CalendarOp.delete => ('Remove this event?', 'Yes, remove it', 'Removed'),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.anchor),
              const SizedBox(width: AppSpacing.sm),
              Text(heading,
                  style: AppText.bodyMedium.copyWith(
                      color: AppColors.anchor, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._body(),
          if (proposal.source case final src?) ...[
            const SizedBox(height: AppSpacing.sm),
            _SourceLink(source: src),
          ],
          const SizedBox(height: AppSpacing.md),
          _footer(yesLabel, doneLabel),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText('DEV · $error',
                  style: AppText.bodySmall.copyWith(
                      color: AppColors.ink, fontFamily: 'monospace')),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body() {
    switch (proposal.op) {
      case CalendarOp.add:
        return [_event(proposal.after!)];
      case CalendarOp.delete:
        return [_event(proposal.before!)];
      case CalendarOp.update:
        return [
          _label('Now'),
          _event(proposal.before!),
          const SizedBox(height: AppSpacing.sm),
          _label('Will become'),
          _event(proposal.after!, emphasize: true),
        ];
    }
  }

  Widget _label(String s) => Text(s.toUpperCase(),
      style: AppText.bodySmall.copyWith(
          color: AppColors.anchor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));

  Widget _event(ProposedEvent e, {bool emphasize = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.title,
              style: AppText.bodyLarge.copyWith(
                  color: AppColors.ink,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500)),
          Text(describeProposedWhen(e) + (e.recurring ? ' · every year' : ''),
              style: AppText.bodySmall.copyWith(color: AppColors.ink)),
        ],
      );

  Widget _footer(String yesLabel, String doneLabel) {
    final (IconData? icon, String? text) = switch (status) {
      ProposalStatus.pending || ProposalStatus.applying => (null, null),
      ProposalStatus.applied => (Icons.check_circle_rounded, doneLabel),
      ProposalStatus.declined => (Icons.remove_circle_outline, 'Left as is'),
      ProposalStatus.failed => (Icons.error_outline, 'Nothing changed'),
    };
    if (text != null) {
      return Row(children: [
        Icon(icon, size: 18, color: AppColors.anchor),
        const SizedBox(width: AppSpacing.xs),
        Text(text,
            style: AppText.bodySmall.copyWith(
                color: AppColors.anchor, fontWeight: FontWeight.w600)),
      ]);
    }
    final busy = status == ProposalStatus.applying;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BondButton(
          label: 'No',
          fullWidth: false,
          variant: BondButtonVariant.ghost,
          onPressed: busy ? null : onNo,
        ),
        const SizedBox(width: AppSpacing.sm),
        BondButton(
          label: yesLabel,
          fullWidth: false,
          loading: busy,
          onPressed: busy ? null : onYes,
        ),
      ],
    );
  }
}

/// A tappable "Source: <title>" line (opens in the browser).
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.source});

  final WebSourceRef source;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(source.url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 14, color: AppColors.anchor),
            const SizedBox(width: 4),
            Flexible(
              child: Text('Source: ${source.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySmall.copyWith(
                      color: AppColors.anchor,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}
