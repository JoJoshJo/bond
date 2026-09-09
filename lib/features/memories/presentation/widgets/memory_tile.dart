import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/memory_models.dart';

/// A square grid tile. Photos show the signed image; videos show their
/// generated first-frame thumbnail with a play overlay, falling back to a
/// play-icon placeholder when no thumbnail exists (e.g. older videos).
class MemoryTile extends StatelessWidget {
  const MemoryTile({
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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: memory.isVideo ? _videoTile() : _photoTile(),
      ),
    );
  }

  Widget _photoTile() {
    return FutureBuilder<String>(
      future: signUrl(memory.mediaPath),
      builder: (context, snap) {
        if (!snap.hasData) return _placeholder();
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, p) => p == null ? child : _placeholder(),
          errorBuilder: (c, e, s) => _placeholder(broken: true),
        );
      },
    );
  }

  Widget _videoTile() {
    return FutureBuilder<String>(
      future: signUrl(memory.thumbPath),
      builder: (context, snap) {
        // No thumbnail (older video / generation failed) → dark fallback.
        final frame = snap.hasData
            ? Image.network(
                snap.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (c, e, s) => _videoFallback(),
              )
            : _videoFallback();
        return Stack(
          fit: StackFit.expand,
          children: [
            frame,
            // Play overlay so a video always reads as a video.
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x33000000)),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 34),
            ),
          ],
        );
      },
    );
  }

  Widget _videoFallback() => Container(color: const Color(0xFF1E2A25));

  Widget _placeholder({bool broken = false}) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Icon(broken ? Icons.broken_image_outlined : Icons.image_outlined,
          color: AppColors.inkFaint),
    );
  }
}
