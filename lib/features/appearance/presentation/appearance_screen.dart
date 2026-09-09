import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/bond_themes.dart';
import '../../../shared/widgets/widgets.dart';
import '../../premium/application/entitlement_providers.dart';
import '../../premium/presentation/paywall_screen.dart';
import '../application/theme_providers.dart';

/// Theme picker. Mint is free; the rest are BOND+ (locked for free users → the
/// paywall). Tapping a theme applies it live and persists it on-device.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final current = ref.watch(themeControllerProvider);

    return BondScaffold(
      title: 'Appearance',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text('Pick a look for your space.',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final theme in bondThemes)
                _ThemeSwatch(
                  theme: theme,
                  selected: theme.key == current,
                  locked: theme.premium && !isPremium,
                  onTap: () {
                    if (theme.premium && !isPremium) {
                      PaywallScreen.open(context);
                    } else {
                      ref.read(themeControllerProvider.notifier).select(theme.key);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!isPremium)
            Text('Mint is free. The rest come with BOND+ 🤍',
                style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final BondTheme theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            Container(
              height: 92,
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.mint : AppColors.border,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Stack(
                children: [
                  // Mini preview: a surface card + an accent chip.
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: p.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              height: 14,
                              width: 14,
                              decoration: BoxDecoration(
                                  color: p.mint, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              height: 14,
                              width: 14,
                              decoration: BoxDecoration(
                                  color: p.mintSoft, shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: AppColors.mint, shape: BoxShape.circle),
                        child: Icon(Icons.check,
                            size: 12, color: AppColors.onMint),
                      ),
                    ),
                  if (locked)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.lock_rounded,
                          size: 16, color: p.inkFaint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(theme.label,
                style: AppText.bodySmall.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
