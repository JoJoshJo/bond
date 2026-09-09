import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/legal_content.dart';

/// Displays a legal document (Terms of Service or Privacy Policy).
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  /// Convenience constructors.
  factory LegalScreen.terms() => const LegalScreen(
        title: 'Terms of Service',
        sections: LegalContent.termsOfService,
      );
  factory LegalScreen.privacy() => const LegalScreen(
        title: 'Privacy Policy',
        sections: LegalContent.privacyPolicy,
      );

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: title,
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Last updated: ${LegalContent.lastUpdated}',
              style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          for (final s in sections) ...[
            Text(s.heading, style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            Text(s.body, style: AppText.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}
