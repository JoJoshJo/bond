import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../data/memory_models.dart';

/// In-app "N years ago today" flashback surfaced at the top of the vault.
class FlashbackCard extends StatelessWidget {
  const FlashbackCard({
    super.key,
    required this.memory,
    required this.signUrl,
    required this.onTap,
  });

  final Memory memory;
  final Future<String> Function(String path) signUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final years = DateTime.now().year - memory.takenAt.year;
    final label = years == 1 ? '1 year ago today 🤍' : '$years years ago today 🤍';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.mintWash,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.mintSoft),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 64,
                width: 64,
                child: memory.isVideo
                    ? Container(
                        color: const Color(0xFF1E2A25),
                        child: const Icon(Icons.play_circle_fill,
                            color: Colors.white70),
                      )
                    : FutureBuilder<String>(
                        future: signUrl(memory.mediaPath),
                        builder: (c, snap) => snap.hasData
                            ? Image.network(snap.data!, fit: BoxFit.cover)
                            : Container(color: AppColors.surfaceAlt),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.label),
                  if (memory.caption != null)
                    Text(memory.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.mintDeep),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}
