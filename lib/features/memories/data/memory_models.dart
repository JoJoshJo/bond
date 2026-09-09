import 'package:flutter/foundation.dart';

/// A shared memory (couple-owned). `mediaPath` is the Storage object path;
/// sign-on-view like chat media.
@immutable
class Memory {
  const Memory({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.takenAt,
    this.caption,
  });

  final String id;
  final String mediaPath;
  final String mediaType; // 'photo' | 'video'
  final DateTime takenAt; // date
  final String? caption;

  bool get isVideo => mediaType == 'video';

  /// Storage path for a video's generated first-frame thumbnail, by convention
  /// `{coupleId}/memories/{id}_thumb.jpg` (the video path with its extension
  /// swapped). Older videos may not have one — sign-on-view degrades gracefully.
  String get thumbPath {
    final dot = mediaPath.lastIndexOf('.');
    final base = dot == -1 ? mediaPath : mediaPath.substring(0, dot);
    return '${base}_thumb.jpg';
  }

  factory Memory.fromRow(Map<String, dynamic> row) => Memory(
        id: row['id'] as String,
        mediaPath: row['media_url'] as String,
        mediaType: (row['media_type'] as String?) ?? 'photo',
        takenAt: DateTime.parse(row['taken_at'] as String),
        caption: row['caption'] as String?,
      );
}
