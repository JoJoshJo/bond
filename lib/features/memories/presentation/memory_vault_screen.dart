import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../premium/application/entitlement_providers.dart';
import '../../premium/presentation/paywall_screen.dart';
import '../application/memory_controller.dart';
import '../application/memory_resurface.dart';
import '../data/memory_models.dart';
import 'add_memory_screen.dart';
import 'memory_viewer_screen.dart';
import 'widgets/memory_tile.dart';

/// The shared memory vault: an "on this day" band, then a month-grouped
/// scrapbook timeline (one card per memory), and an add-memory entry point.
class MemoryVaultScreen extends ConsumerWidget {
  const MemoryVaultScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoryVaultProvider(coupleId));
    final controller = ref.read(memoryVaultProvider(coupleId).notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Memories', style: AppText.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Add memory',
            onPressed: () => _addSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const BondSkeletonGrid()
            : state.isEmpty
                ? _empty(context, ref)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      if (state.flashback case final f?) ...[
                        _OnThisDayBand(
                          found: f,
                          signUrl: controller.signedUrl,
                          onTap: () =>
                              _openViewer(context, f.memory, controller),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      for (final group in state.groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: AppSpacing.md, bottom: AppSpacing.md),
                          child: Text(group.label,
                              style: AppText.title
                                  .copyWith(color: AppColors.anchor)),
                        ),
                        for (final m in group.memories) ...[
                          _MemoryCard(
                            memory: m,
                            signUrl: controller.signedUrl,
                            onTap: () => _openViewer(context, m, controller),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    return BondEmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'Start your collection',
      message: 'Save the little moments together — they\'ll all live here.',
      action: BondButton(
        label: 'Add your first memory',
        fullWidth: false,
        onPressed: () => _addSheet(context, ref),
      ),
    );
  }

  /// Friendly "you've filled your free vault" prompt → the paywall.
  void _showVaultFull(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: AppColors.mintDeep, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text('Your free vault is full',
                  textAlign: TextAlign.center, style: AppText.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You\'ve saved $kFreeMemoryCap memories together. Upgrade to '
                'Usora+ for unlimited memories 🤍',
                textAlign: TextAlign.center,
                style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              BondButton(
                label: 'See Usora+',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  PaywallScreen.open(context);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BondButton(
                label: 'Not now',
                variant: BondButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(
      BuildContext context, Memory memory, MemoryVaultController controller) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          MemoryViewerScreen(memory: memory, signUrl: controller.signedUrl),
    ));
  }

  Future<void> _addSheet(BuildContext context, WidgetRef ref) async {
    // Free-tier cap (client-side for now — NOT server-enforced yet; real
    // enforcement is a count check in RLS / an Edge Function later).
    final premium = ref.read(isPremiumProvider);
    final count = ref.read(memoryVaultProvider(coupleId)).totalCount;
    if (!premium && count >= kFreeMemoryCap) {
      _showVaultFull(context);
      return;
    }

    final picker = ImagePicker();

    Future<void> pick(bool isVideo, ImageSource source) async {
      final x = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source, maxWidth: 2400);
      if (x == null || !context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AddMemoryScreen(
          coupleId: coupleId,
          localPath: x.path,
          isVideo: isVideo,
        ),
      ));
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tile(ctx, Icons.photo_camera_outlined, 'Take a photo',
                () => pick(false, ImageSource.camera)),
            _tile(ctx, Icons.photo_library_outlined, 'Choose a photo',
                () => pick(false, ImageSource.gallery)),
            _tile(ctx, Icons.videocam_outlined, 'Record a video',
                () => pick(true, ImageSource.camera)),
            _tile(ctx, Icons.video_library_outlined, 'Choose a video',
                () => pick(true, ImageSource.gallery)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.mint),
      title: Text(label, style: AppText.bodyLarge),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }
}

/// One scrapbook card: the rounded photo (or video poster), then the caption
/// (if any) and the date. Text is ink/anchor on white — never inkMuted.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard(
      {required this.memory, required this.signUrl, required this.onTap});

  final Memory memory;
  final Future<String> Function(String path) signUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = memory.caption?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    return BondCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      radius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: IgnorePointer(
              // The whole card is the tap target.
              child: MemoryTile(memory: memory, signUrl: signUrl, onTap: () {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasCaption)
                        Text(caption,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyLarge
                                .copyWith(color: AppColors.ink)),
                      Text(memoryLongDate(memory.takenAt),
                          style: AppText.bodySmall.copyWith(
                              color: hasCaption
                                  ? AppColors.ink
                                  : AppColors.anchor,
                              fontWeight: hasCaption
                                  ? FontWeight.w400
                                  : FontWeight.w600)),
                    ],
                  ),
                ),
                // Decorative only — memories have no reactions in the model.
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
                  child: ExcludeSemantics(
                    child: Icon(Icons.favorite_rounded,
                        size: 18, color: AppColors.mintSoft),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "A year ago today" band — warm pale gold, same on-this-day logic as home.
class _OnThisDayBand extends StatelessWidget {
  const _OnThisDayBand(
      {required this.found, required this.signUrl, required this.onTap});

  final ResurfacedMemory found;
  final Future<String> Function(String path) signUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    return Material(
      color: AppColors.accentWash,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: IgnorePointer(
                  child: MemoryTile(
                      memory: found.memory, signUrl: signUrl, onTap: () {}),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(found.eyebrow.toUpperCase(),
                        style: AppText.bodySmall.copyWith(
                            color: AppColors.onAccentWash,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    Text(found.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(color: AppColors.ink)),
                    Text(memoryLongDate(found.memory.takenAt),
                        style: AppText.bodySmall
                            .copyWith(color: AppColors.ink)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppColors.onAccentWash),
            ],
          ),
        ),
      ),
    );
  }
}
