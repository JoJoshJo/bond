import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/widgets.dart';

/// TEMPORARY: a visual gallery of every design token + component, for reviewing
/// the design system on-device against the warmth watch-out. Not part of the
/// real app flow; remove (or gate) before shipping.
class StyleGalleryScreen extends StatelessWidget {
  const StyleGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return BondScaffold(
      title: 'Design system',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _section('Colors'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Swatch('bg', AppColors.bg),
              _Swatch('bgAlt', AppColors.bgAlt),
              _Swatch('surface', AppColors.surface),
              _Swatch('surfaceAlt', AppColors.surfaceAlt),
              _Swatch('mint', AppColors.mint),
              _Swatch('mintSoft', AppColors.mintSoft),
              _Swatch('mintWash', AppColors.mintWash),
              _Swatch('mintDeep', AppColors.mintDeep),
              _Swatch('ink', AppColors.ink),
              _Swatch('inkMuted', AppColors.inkMuted),
              _Swatch('success', AppColors.success),
              _Swatch('warning', AppColors.warning),
              _Swatch('error', AppColors.error),
            ],
          ),
          _section('Typography'),
          Text('Display Large', style: AppText.displayLarge),
          Text('Display Medium', style: AppText.displayMedium),
          Text('Headline', style: AppText.headline),
          Text('Title', style: AppText.title),
          Text('Body large — DM Sans for reading.', style: AppText.bodyLarge),
          Text('Body medium — the workhorse.', style: AppText.bodyMedium),
          Text('Body small / muted.', style: AppText.bodySmall),
          Text('12:34 · mono timestamp', style: AppText.mono),
          _section('Buttons'),
          const BondButton(label: 'Primary', onPressed: _noop),
          const SizedBox(height: AppSpacing.sm),
          const BondButton(
              label: 'Secondary',
              variant: BondButtonVariant.secondary,
              onPressed: _noop),
          const SizedBox(height: AppSpacing.sm),
          const BondButton(
              label: 'Ghost',
              variant: BondButtonVariant.ghost,
              onPressed: _noop),
          const SizedBox(height: AppSpacing.sm),
          const BondButton(label: 'Loading', loading: true, onPressed: _noop),
          const SizedBox(height: AppSpacing.sm),
          const BondButton(label: 'Disabled', onPressed: null),
          _section('Card'),
          BondCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Soft rounded surface', style: AppText.title),
                const SizedBox(height: AppSpacing.xs),
                Text('Gentle shadow, warm — the signature look.',
                    style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          _section('Input'),
          BondTextField(controller: controller, label: 'Email'),
          _section('Chips'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              BondChip(label: 'Mint'),
              BondChip(label: 'Neutral', tone: BondChipTone.neutral),
              BondChip(label: 'Linked', tone: BondChipTone.success, icon: Icons.favorite),
              BondChip(label: 'Pending', tone: BondChipTone.warning),
              BondChip(label: 'Expired', tone: BondChipTone.error),
            ],
          ),
          _section('List tile'),
          BondCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                BondListTile(
                  leadingIcon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Name, photo, timezone',
                  trailing: Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  onTap: () {},
                ),
                const Divider(),
                BondListTile(
                  leadingIcon: Icons.favorite_border,
                  title: 'Our space',
                  trailing: Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  onTap: () {},
                ),
              ],
            ),
          ),
          _section('Loading'),
          const BondLoader(),
          const SizedBox(height: AppSpacing.md),
          const BondShimmer(height: 18),
          const SizedBox(height: AppSpacing.sm),
          const BondShimmer(height: 18, width: 180),
          _section('Empty state'),
          BondCard(
            child: BondEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No memories yet',
              message: 'Photos you save together will show up here.',
              action: BondButton(
                label: 'Add one',
                fullWidth: false,
                onPressed: _noop,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  static void _noop() {}

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(
            top: AppSpacing.xxl, bottom: AppSpacing.md),
        child: Text(label.toUpperCase(),
            style: AppText.bodySmall.copyWith(
              color: AppColors.mintDeep,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(name,
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(fontSize: 10)),
        ),
      ],
    );
  }
}
