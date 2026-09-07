import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../application/couple_providers.dart';
import '../data/couple_repository.dart';

/// Partner A's screen while waiting for B. Shows a QR + shareable link carrying
/// the invite token, a regenerate option, and reacts to the Realtime status
/// change the instant B joins (simultaneous unlock).
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  void _copyLink() {
    final url = _invite?.inviteUrl;
    if (url == null) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied.')),
    );
  }

  void _shareLink() {
    final invite = _invite;
    if (invite == null) return;
    // Include the raw code too, since deep-link auto-open lands with the OAuth
    // task — until then B can paste the code or scan the QR.
    SharePlus.instance.share(
      ShareParams(
        text: 'Join me on BOND 💛\n${invite.inviteUrl}\n\n'
            'Or open BOND → Join → enter code: ${invite.token}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Simultaneous unlock: when B joins, couple status flips to 'active'.
    ref.listen(coupleStatusProvider(widget.coupleId), (_, next) {
      final status = next.asData?.value;
      if (status == 'active' || status == 'sealed') {
        ref.invalidate(myMembershipProvider); // CoupleGate → Home for both.
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.coupleName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text('Invite your partner',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Have them scan this, or send the link. You\'ll both '
                      'unlock the moment they join.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 24),
                    if (_invite != null) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE3ECE8)),
                          ),
                          child: QrImageView(
                            data: _invite!.inviteUrl,
                            size: 220,
                            backgroundColor: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyLink,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Copy link'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.mint,
                                foregroundColor: AppColors.ink,
                              ),
                              onPressed: _shareLink,
                              icon: const Icon(Icons.ios_share_rounded, size: 18),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _regenerating ? null : _regenerate,
                        child: _regenerating
                            ? const Text('Regenerating…')
                            : const Text('Regenerate link'),
                      ),
                    ] else
                      const Text('No active invite — regenerate one below.',
                          textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text('Waiting for your partner…',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppColors.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
