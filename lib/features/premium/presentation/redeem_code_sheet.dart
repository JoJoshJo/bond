import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../application/entitlement_providers.dart';
import '../data/promo_repository.dart';

final promoRepositoryProvider = Provider<PromoRepository>(
  (ref) => PromoRepository(ref.watch(supabaseClientProvider)),
);

/// "Redeem a code" — a small sheet with one field. Validation + the premium
/// grant happen server-side (`redeem_promo_code`); this only sends the text.
class RedeemCodeSheet extends ConsumerStatefulWidget {
  const RedeemCodeSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (_) => const RedeemCodeSheet(),
      );

  @override
  ConsumerState<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends ConsumerState<RedeemCodeSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  PromoResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy || _controller.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref.read(promoRepositoryProvider).redeem(_controller.text);
    if (!mounted) return;
    if (result.outcome == PromoOutcome.ok) {
      // Realtime also catches this; refresh now so it flips immediately.
      ref.invalidate(entitlementProvider);
    }
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${_months[l.month - 1]} ${l.day}, ${l.year}';
  }

  (String, bool) _message(PromoResult r) => switch (r.outcome) {
        PromoOutcome.ok => (
            'Usora+ unlocked for ${r.days ?? 30} days 🤍'
                '${r.expiresAt != null ? '\nEnjoy it until ${_date(r.expiresAt!)}.' : ''}',
            true
          ),
        PromoOutcome.invalid => ('That code isn\'t valid', false),
        PromoOutcome.inactive => ('That code isn\'t active anymore', false),
        PromoOutcome.expired => ('That code has expired', false),
        PromoOutcome.alreadyRedeemed => ('You\'ve already used this code', false),
        PromoOutcome.alreadyPremium => (
            'You already have Usora+'
                '${r.expiresAt != null ? ' (until ${_date(r.expiresAt!)})' : ''} 🤍',
            true
          ),
        PromoOutcome.notLinked =>
          ('Link up with your partner first, then redeem your code together 🤍', false),
        PromoOutcome.error =>
          ('Something went wrong — check your connection and try again', false),
      };

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final success = r?.outcome == PromoOutcome.ok;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Redeem a code', style: AppText.headline),
              const SizedBox(height: AppSpacing.xs),
              Text('Got a Usora+ code? Enter it below.',
                  style: AppText.bodyMedium.copyWith(color: AppColors.ink)),
              const SizedBox(height: AppSpacing.lg),
              if (!success) ...[
                TextField(
                  controller: _controller,
                  enabled: !_busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _redeem(),
                  onChanged: (_) => setState(() {}),
                  style: AppText.bodyLarge.copyWith(letterSpacing: 1.2),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (r != null) ...[
                _ResultNote(text: _message(r).$1, positive: _message(r).$2),
                const SizedBox(height: AppSpacing.md),
              ],
              success
                  ? BondButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : BondButton(
                      label: 'Redeem',
                      loading: _busy,
                      onPressed: _busy || _controller.text.trim().isEmpty
                          ? null
                          : _redeem,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultNote extends StatelessWidget {
  const _ResultNote({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    // Ink on the soft washes (≥4.5:1) — never inkMuted on a tint.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: positive ? AppColors.mintWash : AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(positive ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppText.bodyMedium.copyWith(color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
