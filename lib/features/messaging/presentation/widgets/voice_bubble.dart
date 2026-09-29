import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../data/chat_message.dart';
import '../../../../core/storage/storage_repository.dart';

/// Voice-note bubble with play/pause + progress. Plays the local file while the
/// upload is in flight, otherwise a signed URL for the stored object.
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.storage,
  });

  final ChatMessage message;
  final bool isMine;
  final StorageRepository storage;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loadError = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final local = widget.message.localPath;
      if (local != null && File(local).existsSync()) {
        await _player.setFilePath(local);
      } else if (widget.message.content != null) {
        final url = await widget.storage.signedUrl(widget.message.content!);
        await _player.setUrl(url);
      }
      _loaded = true;
    } catch (e) {
      debugPrint('voice note load failed: $e');
      _loadError = true;
    }
  }

  Future<void> _toggle() async {
    await _ensureLoaded();
    if (_loadError) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Mine: white on the green bubble. Partner: brand green on the white bubble.
    final fg = widget.isMine ? AppColors.onChatMine : AppColors.chatMine;
    final text = widget.isMine ? AppColors.onChatMine : AppColors.inkMuted;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return IconButton(
                onPressed: _toggle,
                tooltip: playing ? 'Pause voice note' : 'Play voice note',
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 36,
                  color: fg,
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                final frac = total.inMilliseconds == 0
                    ? 0.0
                    : (pos.inMilliseconds / total.inMilliseconds)
                        .clamp(0.0, 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Waveform(seed: widget.message.id, progress: frac, color: fg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _loadError
                          ? 'Unavailable'
                          : (total == Duration.zero
                              ? 'Voice note'
                              : _fmt(pos == Duration.zero ? total : pos)),
                      style: AppText.bodySmall.copyWith(color: text),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice-note "waveform": rounded bars that fill with [color] as playback
/// advances. No amplitude data is stored for voice notes, so bar heights are a
/// stable DECORATIVE pattern seeded from the message id (same note → same
/// shape), not the real audio envelope.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed, required this.progress, required this.color});

  final String seed;
  final double progress;
  final Color color;

  static const _bars = 26;

  @override
  Widget build(BuildContext context) {
    var h = seed.hashCode & 0x7fffffff;
    final heights = List<double>.generate(_bars, (i) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      // Taper the ends so it reads as a clip, not a flat block.
      final taper = 0.55 + 0.45 * (1 - ((i - _bars / 2).abs() / (_bars / 2)));
      return (0.3 + (h % 70) / 100) * taper;
    });
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _bars; i++)
            Expanded(
              child: Center(
                child: Container(
                  width: 2.6,
                  height: 26 * heights[i],
                  decoration: BoxDecoration(
                    color: (i + 0.5) / _bars <= progress
                        ? color
                        : color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
