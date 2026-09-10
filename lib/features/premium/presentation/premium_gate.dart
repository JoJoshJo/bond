import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/entitlement_providers.dart';
import 'paywall_screen.dart';

/// The reusable gating pattern: wrap any premium feature. When the couple is
/// Usora+, renders [child]; otherwise renders a tidy lock card that opens the
/// paywall. Adding a future premium feature = wrap it in one of these.
///
/// While the entitlement is still loading, [isPremiumProvider] reports false, so
/// the gate stays locked (never flashes premium content).
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.featureName,
    required this.child,
    this.blurb,
  });

  /// Name shown on the lock card, e.g. 'Calendar' or 'Creature customization'.
  final String featureName;

  /// A one-line description of what unlocking gives.
  final String? blurb;

  /// The premium feature UI, shown only to Usora+ couples.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isPremiumProvider)) return child;
    return _LockCard(featureName: featureName, blurb: blurb);
  }
}

class _LockCard extends StatelessWidget {
  const _LockCard({required this.featureName, this.blurb});

  final String featureName;
  final String? blurb;

  @override
  Widget build(BuildContext context) {
    return BondCard(
      onTap: () => PaywallScreen.open(context),
      color: AppColors.mintWash,
      elevated: false,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, color: AppColors.mintDeep),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$featureName · Usora+', style: AppText.title),
                const SizedBox(height: 2),
                Text(
                  blurb ?? 'Tap to unlock with Usora+.',
                  style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.mintDeep),
        ],
      ),
    );
  }
}
