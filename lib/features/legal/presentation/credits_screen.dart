import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';

/// Third-party data attributions (TMDB, Foursquare) — required by their terms.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: 'Credits',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text('Usora is built with the help of these services 🤍',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          BondCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Movies & shows', style: AppText.title),
                const SizedBox(height: AppSpacing.md),
                SvgPicture.asset('assets/images/tmdb_logo.svg', height: 26),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This product uses the TMDB API but is not endorsed or '
                  'certified by TMDB.',
                  style: AppText.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BondCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Places', style: AppText.title),
                const SizedBox(height: AppSpacing.sm),
                Text('Nearby places are powered by Foursquare.',
                    style: AppText.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
