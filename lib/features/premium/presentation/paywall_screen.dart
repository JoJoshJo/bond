import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../core/config/app_config.dart';
import '../../../core/purchases/purchase_service.dart';
import '../../legal/presentation/legal_screen.dart';
import '../application/entitlement_providers.dart';
import '../application/purchase_providers.dart';

/// The Usora+ upgrade screen — the conversion moment. Warm, benefit-led.
///
/// Subscribe runs the real RevenueCat/StoreKit purchase for the
/// `usora_plus_monthly` package. Only when dev tools are enabled
/// ([kShowDevTools]) and no package is available does it fall back to flipping
/// the in-memory dev override, so testing works where RC can't load. In
/// production a missing package shows an honest "store unavailable" error.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );

  // Only list what actually ships AND is gated behind Usora+ (Guideline 2.3.1).
  static const _benefits = <(IconData, String, String)>[
    (Icons.event_available_rounded, 'Shared calendar',
        'Plan your dates together.'),
    (Icons.smart_toy_rounded, 'Creature date-keeper',
        'Let your creature add and track dates for you.'),
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
          const SizedBox(height: AppSpacing.md),
          _disclosures(context),
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
    final packageAsync = ref.watch(monthlyPackageProvider);
    final package = packageAsync.asData?.value;
    // While offerings are still loading, keep Subscribe busy so an early tap
    // can't hit the "no package" path before RevenueCat has answered.
    final loadingOfferings = packageAsync.isLoading;
    final price = package?.storeProduct.priceString ?? '\$7.99';

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
              Text(price, style: AppText.displayMedium),
              const SizedBox(width: 4),
              Text(_periodLabel(package?.storeProduct.subscriptionPeriod),
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
            loading: loadingOfferings,
            onPressed: () => _subscribe(context, ref, package),
          ),
          const SizedBox(height: AppSpacing.sm),
          BondButton(
            label: 'Restore purchases',
            variant: BondButtonVariant.ghost,
            onPressed: () => _restore(context, ref),
          ),
        ],
      ),
    );
  }

  /// Billing period from the store product's ISO 8601 period (e.g. `P1M` →
  /// "/ month", `P1Y` → "/ year", `P3M` → "/ 3 months"). Falls back to
  /// "/ month" only when the product isn't loaded.
  static String _periodLabel(String? iso) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso ?? '');
    if (match == null) return '/ month';
    final count = int.parse(match.group(1)!);
    const units = {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'};
    final unit = units[match.group(2)]!;
    return count == 1 ? '/ $unit' : '/ $count ${unit}s';
  }

  /// Apple-required subscription disclosures (Guideline 3.1.2): auto-renewal
  /// terms plus working Terms of Service and Privacy Policy links. Sits on the page
  /// background (not the mint card) so the small text keeps WCAG contrast.
  Widget _disclosures(BuildContext context) {
    final linkStyle = AppText.bodySmall.copyWith(
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Column(
      children: [
        Text(
          'Payment will be charged to your Apple ID account at confirmation of '
          'purchase. Subscription automatically renews unless canceled at least '
          '24 hours before the end of the current period. Manage or cancel '
          'anytime in your App Store settings.',
          textAlign: TextAlign.center,
          style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalScreen.terms())),
              child: Text('Terms of Service', style: linkStyle),
            ),
            Text('·', style: AppText.bodySmall),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalScreen.privacy())),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _subscribe(
      BuildContext context, WidgetRef ref, Package? package) async {
    if (package == null) {
      // Dev/testing builds only: no live package (Android / RC unavailable) →
      // flip the dev override so premium can still be exercised end-to-end.
      if (kShowDevTools) {
        ref.read(premiumDevOverrideProvider.notifier).state = true;
        _snack(context, 'Usora+ enabled (dev). Real purchases run on iOS.');
        Navigator.of(context).maybePop();
        return;
      }
      // Production: never fake a purchase. Be honest, and re-fetch offerings so
      // a retry can pick up the package once RevenueCat is reachable.
      ref.invalidate(monthlyPackageProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'The store isn\'t available right now — please try again in a moment.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => ref.invalidate(monthlyPackageProvider),
        ),
      ));
      return;
    }
    final outcome = await ref.read(purchaseServiceProvider).purchase(package);
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        Haptics.success();
        _snack(context, 'Welcome to Usora+ 🤍');
        Navigator.of(context).maybePop();
      case PurchaseOutcome.pending:
        _snack(context, 'Purchase received — unlocking shortly.');
        Navigator.of(context).maybePop();
      case PurchaseOutcome.cancelled:
        break; // user backed out — say nothing
      case PurchaseOutcome.error:
      case PurchaseOutcome.unavailable:
        _snack(context, 'That didn\'t go through — please try again.');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final restored = await ref.read(purchaseServiceProvider).restore();
    if (!context.mounted) return;
    if (restored) {
      _snack(context, 'Purchases restored 🤍');
      Navigator.of(context).maybePop();
    } else {
      _snack(context, 'No purchases to restore.');
    }
  }

  void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}
