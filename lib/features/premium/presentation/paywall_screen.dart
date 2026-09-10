import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/entitlement_providers.dart';

/// The Usora+ upgrade screen — the conversion moment. Warm, benefit-led.
///
/// The Subscribe button is a DEV STUB for now: it flips the in-memory dev
/// override on so premium can be exercised end-to-end. The real RevenueCat
/// purchase call slots in at [_subscribe] later — one call site.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );

  static const _benefits = <(IconData, String, String)>[
    (Icons.auto_awesome_rounded, 'A creature that\'s fully yours',
        'Outfits, looks, personality depth, evolutions.'),
    (Icons.event_available_rounded, 'Calendar management',
        'Connect your Google/Apple calendar — the creature weaves in your dates.'),
    (Icons.smart_toy_rounded, 'Richer AI assistant',
        'Deeper "do things for us" tasks, personalized to your relationship.'),
    (Icons.photo_library_rounded, 'Unlimited memories',
        'No cap on your shared vault — keep every moment.'),
    (Icons.insights_rounded, 'Insights',
        'Gentle read-outs on how you\'re connecting over time.'),
    (Icons.palette_rounded, 'Themes',
        'Make the space feel like the two of you.'),
    (Icons.local_fire_department_rounded, 'Spicy mode',
        'Opt-in-by-both playful extras (18+).'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BondScaffold(
      title: 'Usora+',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _hero(),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < _benefits.length; i++) ...[
            _benefitRow(_benefits[i])
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 260.ms)
                .slideY(begin: 0.15, end: 0),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
          _priceCard(context, ref),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Connection is always free. Usora+ adds depth and delight. 🤍',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Container(
          height: 84,
          width: 84,
          decoration: BoxDecoration(
            color: AppColors.mintWash,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.workspace_premium_rounded,
              color: AppColors.mintDeep, size: 44),
        ).animate().scaleXY(
            begin: 0.7, end: 1, duration: 420.ms, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.lg),
        Text('Unlock Usora+',
            textAlign: TextAlign.center, style: AppText.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Go deeper together — a creature that\'s truly yours, and more room to grow.',
          textAlign: TextAlign.center,
          style: AppText.bodyLarge.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }

  Widget _benefitRow((IconData, String, String) b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.mintWash,
            shape: BoxShape.circle,
          ),
          child: Icon(b.$1, color: AppColors.mint, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.$2, style: AppText.title),
              const SizedBox(height: 2),
              Text(b.$3,
                  style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceCard(BuildContext context, WidgetRef ref) {
    return BondCard(
      color: AppColors.mintWash,
      elevated: false,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$7.99', style: AppText.displayMedium),
              const SizedBox(width: 4),
              Text('/ month',
                  style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('One subscription covers both of you.',
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: AppColors.mintDeep)),
          const SizedBox(height: AppSpacing.lg),
          BondButton(
            label: 'Subscribe',
            icon: Icons.favorite_rounded,
            onPressed: () => _subscribe(context, ref),
          ),
        ],
      ),
    );
  }

  // DEV STUB. Real RevenueCat purchase wires in HERE later (one call site):
  // on success the RC webhook writes the subscriptions row and the app picks it
  // up via entitlementProvider — the dev override below goes away entirely.
  void _subscribe(BuildContext context, WidgetRef ref) {
    ref.read(premiumDevOverrideProvider.notifier).state = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Usora+ enabled (dev). Real purchase wiring comes with RevenueCat.'),
      ),
    );
    Navigator.of(context).maybePop();
  }
}
