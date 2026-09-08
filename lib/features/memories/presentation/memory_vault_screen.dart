import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/memory_controller.dart';
import '../data/memory_models.dart';
import 'add_memory_screen.dart';
import 'memory_viewer_screen.dart';
import 'widgets/flashback_card.dart';
import 'widgets/memory_tile.dart';

/// The shared memory vault: a month-grouped timeline grid, an in-app flashback
/// card, and an add-memory entry point.
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
            onPressed: () => _addSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const BondLoader()
            : state.isEmpty
                ? _empty(context)
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      if (state.flashbacks.isNotEmpty)
                        FlashbackCard(
                          memory: state.flashbacks.first,
                          signUrl: controller.signedUrl,
                          onTap: () =>
                              _openViewer(context, state.flashbacks.first, controller),
                        ),
                      for (final group in state.groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm, top: AppSpacing.sm),
                          child: Text(group.label, style: AppText.title),
                        ),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          children: [
                            for (final m in group.memories)
                              MemoryTile(
                                memory: m,
                                signUrl: controller.signedUrl,
                                onTap: () => _openViewer(context, m, controller),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return BondEmptyState(
      icon: Icons.photo_library_outlined,
      title: 'No memories yet',
      message: 'Photos and videos you save together will live here.',
      action: BondButton(
        label: 'Add your first',
        fullWidth: false,
        onPressed: () => _addSheet(context),
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

  Future<void> _addSheet(BuildContext context) async {
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
