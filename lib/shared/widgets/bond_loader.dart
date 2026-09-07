import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// On-brand centered spinner.
class BondLoader extends StatelessWidget {
  const BondLoader({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.6,
          color: AppColors.mint,
        ),
      ),
    );
  }
}

/// A soft shimmer skeleton block for loading states (hand-rolled, no package).
class BondShimmer extends StatefulWidget {
  const BondShimmer({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = AppRadius.sm,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<BondShimmer> createState() => _BondShimmerState();
}

class _BondShimmerState extends State<BondShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _c.value, 0),
              end: Alignment(1 - 2 * _c.value, 0),
              colors: const [
                AppColors.surfaceAlt,
                AppColors.mintWash,
                AppColors.surfaceAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}
