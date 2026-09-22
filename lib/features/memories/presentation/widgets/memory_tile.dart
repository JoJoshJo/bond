import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/memory_models.dart';

/// A square grid tile. Photos show the signed image; videos show a first-frame
/// poster (the stored thumbnail when present, otherwise generated on-device from
/// the video) with a play overlay — like a normal gallery.
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
        child: memory.isVideo
            ? _VideoThumb(memory: memory, signUrl: signUrl)
            : _photoTile(),
      ),
    );
  }

  Widget _photoTile() {
    return FutureBuilder<String>(
      future: signUrl(memory.mediaPath),
      builder: (context, snap) {
        if (!snap.hasData) return const _NeutralPlaceholder();
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, p) =>
              p == null ? child : const _NeutralPlaceholder(),
          errorBuilder: (c, e, s) => const _NeutralPlaceholder(broken: true),
        );
      },
    );
  }
}

/// Video poster tile: fast stored thumbnail → on-device first-frame fallback →
/// subtle placeholder, with a play icon overlaid. Generated frames are cached
/// (by memory id) so scrolling doesn't regenerate.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.memory, required this.signUrl});

  final Memory memory;
  final Future<String> Function(String path) signUrl;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  // memory.id -> generated frame bytes (null value = generation was tried and
  // failed, so we don't retry it every rebuild).
  static final Map<String, Uint8List?> _genCache = {};

  String? _storedUrl; // signed URL of the stored thumbnail, when it exists
  Uint8List? _genBytes; // on-device generated frame
  bool _done = false; // finished all attempts (for the failed fallback)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1) Fast path: the stored thumbnail. createSignedUrl throws if the object
    //    doesn't exist, so a throw here just means "no stored thumb → generate".
    try {
      final url = await widget.signUrl(widget.memory.thumbPath);
      if (!mounted) return;
      setState(() => _storedUrl = url);
      return;
    } catch (_) {/* fall through to on-device generation */}
    await _generate();
  }

  Future<void> _generate() async {
    if (_genCache.containsKey(widget.memory.id)) {
      if (!mounted) return;
      setState(() {
        _genBytes = _genCache[widget.memory.id];
        _done = true;
      });
      return;
    }
    try {
      final videoUrl = await widget.signUrl(widget.memory.mediaPath);
      final bytes = await VideoThumbnailPlus.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 600,
        quality: 75,
      );
      _genCache[widget.memory.id] = bytes;
      if (!mounted) return;
      setState(() {
        _genBytes = bytes;
        _done = true;
      });
    } catch (e) {
      debugPrint('video thumbnail generation failed: $e');
      _genCache[widget.memory.id] = null;
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _frame(),
        // Scrim keeps the white play icon readable over any frame.
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x33000000))),
        const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
        ),
      ],
    );
  }

  Widget _frame() {
    if (_storedUrl != null) {
      return Image.network(
        _storedUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (c, child, p) =>
            p == null ? child : const _NeutralPlaceholder(),
        // A stored URL that fails to load → try on-device generation.
        errorBuilder: (c, e, s) {
          if (!_done && _genBytes == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
          }
          return _genBytes != null
              ? Image.memory(_genBytes!, fit: BoxFit.cover,
                  width: double.infinity, height: double.infinity)
              : const _NeutralPlaceholder();
        },
      );
    }
    if (_genBytes != null) {
      return Image.memory(_genBytes!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    // Generation finished with no frame → subtle film-icon fallback (not black).
    if (_done) return const _NeutralPlaceholder(video: true);
    // Still working.
    return const _NeutralPlaceholder();
  }
}

/// Neutral loading / fallback fill — soft surface with a subtle icon, never a
/// black void.
class _NeutralPlaceholder extends StatelessWidget {
  const _NeutralPlaceholder({this.broken = false, this.video = false});

  final bool broken;
  final bool video;

  @override
  Widget build(BuildContext context) {
    final IconData icon = broken
        ? Icons.broken_image_outlined
        : video
            ? Icons.movie_outlined
            : Icons.image_outlined;
    return Container(
      color: AppColors.surfaceAlt,
      child: Icon(icon, color: AppColors.inkFaint),
    );
  }
}
