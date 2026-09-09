import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../premium/presentation/paywall_screen.dart';
import '../application/spicy_providers.dart';

/// The Spicy-mode control in the Us tab: a toggle plus the free-tier session
/// countdown / cooldown state, with a paywall nudge when locked.
class SpicySection extends ConsumerStatefulWidget {
  const SpicySection({super.key});

  @override
  ConsumerState<SpicySection> createState() => _SpicySectionState();
}

class _SpicySectionState extends ConsumerState<SpicySection> {
  @override
  void initState() {
    super.initState();
    // Pull the server's authoritative state when the tab opens.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(spicyControllerProvider.notifier).refresh());
  }

  Future<void> _onToggle(bool value) async {
    final controller = ref.read(spicyControllerProvider.notifier);
    if (!value) {
      controller.turnOff();
      return;
    }
    final outcome = await controller.turnOn();
    if (!mounted) return;
    switch (outcome) {
      case SpicyActivateOutcome.activated:
      case SpicyActivateOutcome.unlimited:
        break; // theme flips via the provider
      case SpicyActivateOutcome.cooldown:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Spicy mode is cooling down — upgrade for unlimited.'),
        ));
        PaywallScreen.open(context);
        break;
      case SpicyActivateOutcome.error:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t start spicy mode — try again in a moment.'),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spicyControllerProvider);

    // One-time prompt when a free session auto-expires.
    ref.listen<SpicyState>(spicyControllerProvider, (prev, next) {
      if (next.justEnded && (prev == null || !prev.justEnded)) {
        _showSessionEnded(next);
        ref.read(spicyControllerProvider.notifier).clearJustEnded();
      }
    });

    return BondCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      child: Column(
        children: [
          SwitchListTile(
            value: state.on,
            title: Text('Spicy mode 🌶️', style: AppText.bodyLarge),
            subtitle: Text(_subtitle(state), style: AppText.bodySmall),
            onChanged: state.busy ? null : _onToggle,
          ),
          if (state.inCooldown)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Free spicy is a 3-hour session every 2 weeks.',
                      style: AppText.bodySmall.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => PaywallScreen.open(context),
                    child: const Text('Get BOND+'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle(SpicyState s) {
    if (s.unlimited) return 'Unlimited with BOND+ — on anytime';
    if (s.on && s.expiresAt != null) {
      return 'Active — ends in ${_remaining(s.expiresAt!)}';
    }
    if (s.inCooldown) {
      return 'Available again in ${_remaining(s.cooldownUntil!)}';
    }
    return 'Free: a 3-hour session every 2 weeks';
  }

  void _showSessionEnded(SpicyState s) {
    final tail = s.cooldownUntil != null
        ? 'come back in ${_remaining(s.cooldownUntil!)}'
        : 'come back soon';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Your spicy session ended 🌶️'),
        content: Text(
          'That was your free 3-hour taste. Upgrade to BOND+ for unlimited, '
          'or $tail.',
          style: AppText.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PaywallScreen.open(context);
            },
            child: const Text('See BOND+'),
          ),
        ],
      ),
    );
  }

  /// A coarse "2d" / "5h 12m" / "8m" remaining string.
  String _remaining(DateTime until) {
    final d = until.difference(DateTime.now());
    if (d.isNegative) return 'a moment';
    if (d.inDays >= 1) {
      final days = d.inDays;
      return '$days day${days == 1 ? '' : 's'}';
    }
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}
