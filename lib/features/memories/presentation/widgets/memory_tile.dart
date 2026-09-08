import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/memory_models.dart';

/// A square grid tile. Photos show the signed image; videos show a play-icon
/// placeholder (real thumbnails are a later polish).
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
    return Container(
      color: const Color(0xFF1E2A25),
      child: const Center(
        child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 34),
      ),
    );
  }

  Widget _placeholder({bool broken = false}) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Icon(broken ? Icons.broken_image_outlined : Icons.image_outlined,
          color: AppColors.inkFaint),
    );
  }
}
