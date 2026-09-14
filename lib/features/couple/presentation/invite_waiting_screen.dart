import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/utils/haptics.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/couple_providers.dart';
import '../data/couple_repository.dart';
import 'widgets/creature_placeholder.dart';

/// Partner A's warm "waiting room" while B hasn't joined yet. Keeps the invite
/// tools + the Realtime listener that flips both partners to linked the instant
/// B joins; adds a breathing placeholder, anticipation copy, small setup
/// (rename + start date), and a preview of what unlocks.
class InviteWaitingScreen extends ConsumerStatefulWidget {
  const InviteWaitingScreen({
    super.key,
    required this.coupleId,
    required this.coupleName,
  });

  final String coupleId;
  final String coupleName;

  @override
  ConsumerState<InviteWaitingScreen> createState() =>
      _InviteWaitingScreenState();
}

class _InviteWaitingScreenState extends ConsumerState<InviteWaitingScreen> {
  CoupleInvite? _invite;
  bool _loading = true;
  bool _regenerating = false;

  late String _coupleName = widget.coupleName;
  DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final invite = await ref
          .read(coupleRepositoryProvider)
          .getActiveInvite(widget.coupleId);
      if (mounted) setState(() => _invite = invite);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      final invite = await ref.read(coupleRepositoryProvider).regenerateInvite();
      if (mounted) setState(() => _invite = invite);
    } catch (error) {
      _toast(friendlyError(error));
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  void _copyCode() {
    final code = _invite?.token;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    Haptics.tap();
    _toast('Code copied.');
  }

  void _shareCode() {
    final invite = _invite;
    if (invite == null) return;
    Haptics.tap();
    SharePlus.instance.share(
      ShareParams(
        text: 'Join me on Usora 💚 — open the app, tap Join, '
            'and enter code: ${invite.token}',
      ),
    );
  }

  /// The 6-digit code spaced out for legibility, e.g. "1 2 3 4 5 6".
  String _spacedCode(String code) => code.split('').join(' ');

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renameCouple() async {
    final controller = TextEditingController(text: _coupleName);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPad,
          right: AppSpacing.screenPad,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Name your space', style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            BondTextField(controller: controller, label: 'Couple name'),
            const SizedBox(height: AppSpacing.lg),
            BondButton(
              label: 'Save',
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (newName == null || newName.isEmpty || newName == _coupleName) return;
    setState(() => _coupleName = newName);
    try {
      await ref
          .read(coupleRepositoryProvider)
          .updateCoupleName(widget.coupleId, newName);
      ref.invalidate(myMembershipProvider); // keep gate/name consistent
    } catch (error) {
      _toast(friendlyError(error));
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now, // today-or-earlier, no future dates
      helpText: 'When did you two begin?',
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
    try {
      await ref
          .read(coupleRepositoryProvider)
          .updateRelationshipStartDate(widget.coupleId, picked);
      _toast('Start date saved.');
    } catch (error) {
      _toast(friendlyError(error));
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Simultaneous unlock: when B joins, couple status flips to 'active'.
    ref.listen(coupleStatusProvider(widget.coupleId), (_, next) {
      final status = next.asData?.value;
      if (status == 'active' || status == 'sealed') {
        ref.invalidate(myMembershipProvider); // CoupleGate → Home for both.
      }
    });

    return BondScaffold(
      scrollable: true,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: AppSpacing.huge),
              child: BondLoader(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                _header(),
                const SizedBox(height: AppSpacing.xxl),
                Center(child: const CreaturePlaceholder())
                    .animate()
                    .fadeIn(duration: 600.ms),
                const SizedBox(height: AppSpacing.xxl),
                _anticipationCopy(),
                const SizedBox(height: AppSpacing.xxl),
                _inviteCard(),
                const SizedBox(height: AppSpacing.xxl),
                _prepareSection(),
                const SizedBox(height: AppSpacing.xxl),
                _comingSoon(),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Text('YOUR SPACE',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.mintDeep,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            )),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: _renameCouple,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _coupleName,
                  textAlign: TextAlign.center,
                  style: AppText.displayMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.inkFaint),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _anticipationCopy() {
    return Column(
      children: [
        Text('Your space is ready.',
            textAlign: TextAlign.center, style: AppText.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The moment your partner joins, Usora comes alive for you both.',
          textAlign: TextAlign.center,
          style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        const BondChip(
          label: 'Waiting for your partner',
          tone: BondChipTone.warning,
          icon: Icons.hourglass_empty_rounded,
        ),
      ],
    );
  }

  Widget _inviteCard() {
    final invite = _invite;
    return BondCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite your partner',
              textAlign: TextAlign.center, style: AppText.title),
          const SizedBox(height: AppSpacing.xs),
          Text('Have them scan this, or send the code.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          if (invite != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: QrImageView(
                  data: invite.token,
                  size: 200,
                  backgroundColor: AppColors.surface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // The big, human-readable code for reading aloud or typing in.
            Text(
              _spacedCode(invite.token),
              textAlign: TextAlign.center,
              style: AppText.mono.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: BondButton(
                    label: 'Copy code',
                    variant: BondButtonVariant.secondary,
                    icon: Icons.copy_rounded,
                    onPressed: _copyCode,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: BondButton(
                    label: 'Share code',
                    icon: Icons.ios_share_rounded,
                    onPressed: _shareCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BondButton(
              label: _regenerating ? 'Regenerating…' : 'New code',
              variant: BondButtonVariant.ghost,
              loading: _regenerating,
              onPressed: _regenerate,
            ),
          ] else
            BondButton(
              label: 'Generate code',
              onPressed: _regenerate,
              loading: _regenerating,
            ),
        ],
      ),
    );
  }

  Widget _prepareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text('Preparing our space',
              style: AppText.bodySmall.copyWith(
                color: AppColors.mintDeep,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              )),
        ),
        BondCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              BondListTile(
                leadingIcon: Icons.favorite_border_rounded,
                title: 'Name your space',
                subtitle: _coupleName,
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.inkFaint),
                onTap: _renameCouple,
              ),
              const Divider(),
              BondListTile(
                leadingIcon: Icons.calendar_today_rounded,
                title: 'Relationship start date',
                subtitle: _startDate == null
                    ? 'Optional — add when you began'
                    : _formatDate(_startDate!),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.inkFaint),
                onTap: _pickStartDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _comingSoon() {
    final items = <({IconData icon, String title, String sub})>[
      (icon: Icons.sports_esports_outlined, title: 'Games', sub: 'Play together, live or async'),
      (icon: Icons.question_answer_outlined, title: 'Daily questions', sub: 'A prompt for you both each day'),
      (icon: Icons.photo_library_outlined, title: 'Memories', sub: 'Your shared photo vault'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('What’s coming',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.mintDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                )),
            const SizedBox(width: AppSpacing.sm),
            const BondChip(
                label: 'Unlocks when they join',
                tone: BondChipTone.neutral),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < items.length; i++) ...[
          Opacity(
            opacity: 0.72,
            child: BondCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(items[i].icon,
                        size: 20, color: AppColors.inkMuted),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title, style: AppText.bodyLarge),
                        Text(items[i].sub, style: AppText.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppColors.inkFaint),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: (150 * i).ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
          if (i < items.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
