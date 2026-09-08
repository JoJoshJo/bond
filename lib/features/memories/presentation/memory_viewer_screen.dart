import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../data/memory_models.dart';

/// Full-screen memory viewer: pinch-zoom photos, play videos. Shows caption+date.
class MemoryViewerScreen extends StatefulWidget {
  const MemoryViewerScreen({
    super.key,
    required this.memory,
    required this.signUrl,
  });

  final Memory memory;
  final Future<String> Function(String path) signUrl;

  @override
  State<MemoryViewerScreen> createState() => _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends State<MemoryViewerScreen> {
  VideoPlayerController? _video;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    if (widget.memory.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() => _initializing = true);
    try {
      final url = await widget.signUrl(widget.memory.mediaPath);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _video = c;
        _initializing = false;
      });
      c.play();
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.memory;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: memory.isVideo ? _videoView() : _photoView(),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memory.caption != null) ...[
                  Text(memory.caption!,
                      style: AppText.bodyLarge.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                ],
                Text(_fmtDate(memory.takenAt),
                    style: AppText.bodySmall.copyWith(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoView() {
    return FutureBuilder<String>(
      future: widget.signUrl(widget.memory.mediaPath),
      builder: (context, snap) => snap.hasData
          ? InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(snap.data!),
            )
          : const CircularProgressIndicator(),
    );
  }

  Widget _videoView() {
    final v = _video;
    if (_initializing || v == null) {
      return const CircularProgressIndicator();
    }
    return GestureDetector(
      onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
      child: AspectRatio(
        aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(v),
            VideoProgressIndicator(v, allowScrubbing: true),
            if (!v.value.isPlaying)
              const Icon(Icons.play_circle_fill,
                  color: Colors.white70, size: 64),
          ],
        ),
      ),
    );
  }
}
