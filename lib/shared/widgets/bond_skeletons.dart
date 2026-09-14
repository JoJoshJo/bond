import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'bond_loader.dart';

/// Simple skeleton placeholders built on [BondShimmer], matching the rough
/// shapes of the content they stand in for. Neutral and calm — just enough to
/// signal "loading" without a bare spinner.

/// A single rounded card-shaped shimmer.
class BondSkeletonCard extends StatelessWidget {
  const BondSkeletonCard({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return BondShimmer(height: height, radius: AppRadius.lg);
  }
}

/// A stack of card-shaped shimmers (insights, prompt, generic lists). A
/// non-scrolling Column so it's safe both as a screen body and inside an
/// existing scroll view.
class BondSkeletonCards extends StatelessWidget {
  const BondSkeletonCards({
    super.key,
    this.count = 3,
    this.height = 96,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final int count;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            BondSkeletonCard(height: height),
          ],
        ],
      ),
    );
  }
}

/// Chat-style shimmer bubbles, alternating sides.
class BondSkeletonChat extends StatelessWidget {
  const BondSkeletonChat({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      itemCount: count,
      itemBuilder: (context, i) {
        final mine = i.isEven;
        final width = MediaQuery.of(context).size.width *
            (0.45 + (i % 3) * 0.12); // varied bubble widths
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: BondShimmer(
              height: 40,
              width: width,
              radius: AppRadius.lg,
            ),
          ),
        );
      },
    );
  }
}

/// A 2-column grid of square shimmer tiles (memories vault).
class BondSkeletonGrid extends StatelessWidget {
  const BondSkeletonGrid({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const BondShimmer(height: 160, radius: AppRadius.lg),
    );
  }
}
