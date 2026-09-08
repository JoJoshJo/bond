import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../data/chat_message.dart';
import '../../data/storage_repository.dart';

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
    } catch (_) {
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
    final fg = widget.isMine ? AppColors.onMint : AppColors.ink;
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
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 36,
                  color: fg,
                ),
              );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    final frac = total.inMilliseconds == 0
                        ? 0.0
                        : (pos.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 4,
                            backgroundColor: fg.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(fg),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _loadError
                              ? 'Unavailable'
                              : (total == Duration.zero
                                  ? 'Voice note'
                                  : _fmt(pos == Duration.zero ? total : pos)),
                          style: AppText.bodySmall.copyWith(
                              color: fg.withValues(alpha: 0.8)),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
